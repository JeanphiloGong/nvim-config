#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
entry="$repo_root/tmux/bin/codex-tmux-resurrect-state"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-tmux-resurrect-state.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/bin" "$tmp_root/codex"
rollout="$tmp_root/codex/rollout.jsonl"
: >"$rollout"
python3 - "$tmp_root/codex/state_5.sqlite" "$rollout" <<'PY'
import sqlite3
import sys

with sqlite3.connect(sys.argv[1]) as db:
    db.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, rollout_path TEXT)")
    db.execute(
        "INSERT INTO threads VALUES (?, ?)",
        ("01a00000-0000-7000-8000-000000000001", sys.argv[2]),
    )
PY

cat >"$tmp_root/bin/tmux" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

log="${TMUX_TEST_LOG:?}"
state="${TMUX_TEST_STATE:?}"

case "$1" in
  show)
    case "$*" in
      *'@codex_resurrect_state_file'*) printf '%s\n' "$state" ;;
      *'@codex_last_win'*) printf '%s\n' 'test:0' ;;
      *'@codex_last_pane'*) printf '%s\n' '%old' ;;
      *'@codex_pane_thread_id'*) printf '%s\n' '01a00000-0000-7000-8000-000000000001' ;;
    esac
    ;;
  list-panes)
    if [[ "$*" != *'#{session_name}'* ]]; then
      printf '%s\n' '1'
    else
      [[ "${4:-}" == *$'\t'* ]] || exit 1
      printf 'test\t0\t1\t%old\n'
    fi
    ;;
  display-message)
    if [[ "$*" == *'#{pane_index}'* ]]; then
      printf '%s\n' '1'
    elif [[ "$*" == *'#{pane_id}'* ]]; then
      printf '%s\n' '%new'
    fi
    ;;
  set)
    printf '%s\n' "$*" >>"$log"
    ;;
  refresh-client)
    :
    ;;
esac
SH
chmod +x "$tmp_root/bin/tmux"

state_file="$tmp_root/resurrect-state"
log_file="$tmp_root/tmux.log"

TMUX_TEST_LOG="$log_file" \
TMUX_TEST_STATE="$state_file" \
PATH="$tmp_root/bin:$PATH" \
  "$entry" save

grep -F $'pane\ttest\t0\t1\t01a00000-0000-7000-8000-000000000001' "$state_file" >/dev/null
grep -F $'last\ttest\t0\t1\t01a00000-0000-7000-8000-000000000001' "$state_file" >/dev/null
test "$(stat -c '%a' "$state_file")" = 600

: >"$log_file"
HOME="$tmp_root" \
CODEX_HOME="$tmp_root/codex" \
TMUX_TEST_LOG="$log_file" \
TMUX_TEST_STATE="$state_file" \
PATH="$tmp_root/bin:$PATH" \
  "$entry" restore

grep -F '@codex_pane_thread_id 01a00000-0000-7000-8000-000000000001' "$log_file" >/dev/null
grep -F '@codex_last_win test:0' "$log_file" >/dev/null
grep -F '@codex_last_pane %new' "$log_file" >/dev/null
grep -F '@codex_last_thread_id 01a00000-0000-7000-8000-000000000001' "$log_file" >/dev/null

printf 'codex-tmux-resurrect-state smoke: OK\n'
