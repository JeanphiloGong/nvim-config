#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
entry="$repo_root/tmux/bin/codex-tmux-resurrect"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-tmux-resurrect.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/bin" "$tmp_root/codex"
export CODEX_HOME="$tmp_root/codex"
export CODEX_SQLITE_HOME="$CODEX_HOME"
export TMUX_CODEX_RESURRECT_FILE="$tmp_root/resume.tsv"

saved_id="01a00000-0000-7000-8000-000000000001"
missing_id="01a00000-0000-7000-8000-000000000002"
process_id="01a00000-0000-7000-8000-000000000003"
rollout="$tmp_root/saved.jsonl"
process_rollout="$tmp_root/process.jsonl"
touch "$rollout"
touch "$process_rollout"
python3 - "$CODEX_HOME/state_5.sqlite" "$saved_id" "$rollout" "$process_id" "$process_rollout" <<'PY'
import sqlite3
import sys

with sqlite3.connect(sys.argv[1]) as db:
    db.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, rollout_path TEXT)")
    db.execute("INSERT INTO threads VALUES (?, ?)", (sys.argv[2], sys.argv[3]))
    db.execute("INSERT INTO threads VALUES (?, ?)", (sys.argv[4], sys.argv[5]))
PY

cat >"$tmp_root/bin/tmux" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  list-panes)
    if [[ "$*" == *'#{session_name}'* ]]; then
      format="${*: -1}"
      if [[ "$format" == *'\t'* ]]; then
        printf 'list-panes format contains literal \\t\n' >&2
        exit 1
      fi
      printf 'demo\t0\t0\t%%1\tnode\n'
      printf 'demo-grouped\t0\t0\t%%1\tnode\n'
      printf 'demo\t0\t1\t%%2\tnode\n'
      printf 'demo\t0\t2\t%%3\tbash\n'
      printf 'demo\t0\t3\t%%4\tbash\n'
    else
      printf '0\n1\n'
    fi
    ;;
  show)
    case "$*" in
      *'%1'*'@codex_pane_thread_id'*) printf '%s\n' "$TMUX_TEST_SAVED_THREAD" ;;
      *'%2'*'@codex_pane_thread_id'*) printf '%s\n' "$TMUX_TEST_MISSING_THREAD" ;;
      *'%3'*'@codex_pane_thread_id'*) printf '%s\n' "$TMUX_TEST_SAVED_THREAD" ;;
    esac
    ;;
  has-session)
    exit 0
    ;;
  display-message)
    case "$*" in
      *'-t %4'*'#{pane_tty}'*) printf '%s\n' '/dev/pts/4' ;;
      *'#{pane_current_command}'*) printf '%s\n' 'bash' ;;
      *'@codex_resurrect_restored_thread'*) : ;;
    esac
    ;;
  send-keys|set)
    printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
    ;;
esac
SH
chmod +x "$tmp_root/bin/tmux"

cat >"$tmp_root/bin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *'-t pts/4 -o pid=,comm='*) printf '%s\n' '1234 codex' ;;
esac
SH
chmod +x "$tmp_root/bin/ps"

cat >"$tmp_root/bin/readlink" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  /proc/1234/fd/*) printf '%s/thread-writer-locks/%s.lock\n' "$CODEX_HOME" "$TMUX_TEST_PROCESS_THREAD" ;;
esac
SH
chmod +x "$tmp_root/bin/readlink"

export TMUX_TEST_LOG="$tmp_root/tmux.log"
export TMUX_TEST_SAVED_THREAD="$saved_id"
export TMUX_TEST_MISSING_THREAD="$missing_id"
export TMUX_TEST_PROCESS_THREAD="$process_id"
PATH="$tmp_root/bin:$PATH" "$entry" snapshot
grep -F $'demo\t0\t0\t' "$TMUX_CODEX_RESURRECT_FILE" >/dev/null
grep -F "$saved_id" "$TMUX_CODEX_RESURRECT_FILE" >/dev/null
test "$(grep -Fc "$saved_id" "$TMUX_CODEX_RESURRECT_FILE")" -eq 1
grep -F $'demo\t0\t3\t'"$process_id" "$TMUX_CODEX_RESURRECT_FILE" >/dev/null
grep -F "set -pq -t %4 @codex_pane_thread_id $process_id" "$TMUX_TEST_LOG" >/dev/null
if grep -F "$missing_id" "$TMUX_CODEX_RESURRECT_FILE" >/dev/null; then
  printf 'invalid Codex thread was saved\n' >&2
  exit 1
fi

before_restore_snapshot="$(cat "$TMUX_CODEX_RESURRECT_FILE")"
PATH="$tmp_root/bin:$PATH" "$entry" begin-restore
PATH="$tmp_root/bin:$PATH" "$entry" snapshot
test "$(cat "$TMUX_CODEX_RESURRECT_FILE")" = "$before_restore_snapshot"

: >"$TMUX_TEST_LOG"
PATH="$tmp_root/bin:$PATH" "$entry" restore
grep -F "send-keys -t demo:0.0 codex resume $saved_id C-m" "$TMUX_TEST_LOG" >/dev/null
if grep -F 'demo:0.1' "$TMUX_TEST_LOG" >/dev/null; then
  printf 'invalid Codex pane was restored\n' >&2
  exit 1
fi
test ! -e "${TMUX_CODEX_RESURRECT_FILE}.restoring"

printf 'codex-tmux-resurrect smoke: OK\n'
