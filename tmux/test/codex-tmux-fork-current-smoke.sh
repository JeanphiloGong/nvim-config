#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
entry="$repo_root/tmux/bin/codex-tmux-fork-current"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-tmux-fork.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

saved_id="01a00000-0000-7000-8000-000000000001"
missing_id="01a00000-0000-7000-8000-000000000002"

mkdir -p "$tmp_root/bin"
export CODEX_HOME="$tmp_root/codex"
export CODEX_SQLITE_HOME="$CODEX_HOME"
mkdir -p "$CODEX_HOME"
python3 - "$CODEX_HOME" "$saved_id" <<'PY'
import pathlib, sqlite3, sys
root = pathlib.Path(sys.argv[1])
rollout = root / 'saved.jsonl'
rollout.touch()
with sqlite3.connect(root / 'state_5.sqlite') as db:
    db.execute('CREATE TABLE threads (id TEXT PRIMARY KEY, rollout_path TEXT)')
    db.execute('INSERT INTO threads VALUES (?, ?)', (sys.argv[2], str(rollout)))
PY

cat >"$tmp_root/bin/ps" <<'SH'
#!/usr/bin/env bash
printf '%s\n%s\n' "${TMUX_TEST_PID:-999999}" "${TMUX_TEST_PID:-999999}"
SH

cat >"$tmp_root/bin/tmux" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  display-message)
    if [ "${2:-}" = "-p" ]; then
      case "$*" in
        *'#{pane_tty}'*) printf '%s\n' '/dev/pts/999' ;;
        *'#{pane_current_path}'*) printf '%s\n' "$TMUX_TEST_PANE_PATH" ;;
        *'#{pane_pid}'*) printf '%s\n' '999999' ;;
        *'#{session_name}:#{window_index}'*) printf '%s\n' 'test:0' ;;
      esac
    else
      printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
    fi
    ;;
  show)
    case "$*" in
      *'@codex_pane_thread_id'*)
        if [ -f "$TMUX_TEST_PANE_PATH/pane-id" ]; then
          cat "$TMUX_TEST_PANE_PATH/pane-id"
        else
          printf '%s\n' "$TMUX_TEST_PANE_THREAD_ID"
        fi
        ;;
      *'@codex_history_file'*) printf '%s\n' "$TMUX_TEST_PANE_PATH/history" ;;
      *'@codex_notify_mode'*) printf '%s\n' 'off' ;;
      *'@codex_fork_log_file'*) printf '%s\n' 'off' ;;
    esac
    ;;
  split-window)
    printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
    printf '%s\n' '%forked'
    ;;
  send-keys|set)
    printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
    if [ "$1 ${2:-}" = 'set -p' ] && [ "${5:-}" = '@codex_pane_thread_id' ]; then
      printf '%s\n' "$6" >"$TMUX_TEST_PANE_PATH/pane-id"
    fi
    ;;
esac
SH

chmod +x "$tmp_root/bin/ps" "$tmp_root/bin/tmux"

run_helper() {
  TMUX_PANE='%origin' \
    TMUX_TEST_LOG="$tmp_root/tmux.log" \
    TMUX_TEST_PANE_PATH="$tmp_root" \
    TMUX_TEST_PANE_THREAD_ID="$1" \
    PATH="$tmp_root/bin:$PATH" \
    bash -c 'export TMUX_TEST_PID=$$; exec "$1" v' bash "$entry"
}

: >"$tmp_root/tmux.log"
CODEX_SESSION_ID="$missing_id" CODEX_THREAD_ID="$saved_id" run_helper ""
grep -F "codex fork $saved_id" "$tmp_root/tmux.log" >/dev/null

: >"$tmp_root/tmux.log"
CODEX_SESSION_ID="$missing_id" CODEX_THREAD_ID='' run_helper ""
if grep -F 'split-window' "$tmp_root/tmux.log" >/dev/null; then
  printf 'missing session id created a pane\n' >&2
  exit 1
fi
grep -F 'Codex fork: no sid' "$tmp_root/tmux.log" >/dev/null

: >"$tmp_root/tmux.log"
CODEX_SESSION_ID="$missing_id" CODEX_THREAD_ID='' run_helper "$saved_id"
grep -F 'split-window' "$tmp_root/tmux.log" >/dev/null
grep -F "codex fork $saved_id" "$tmp_root/tmux.log" >/dev/null

: >"$tmp_root/tmux.log"
TMUX_PANE='%origin' TMUX_TEST_LOG="$tmp_root/tmux.log" \
  TMUX_TEST_PANE_PATH="$tmp_root" TMUX_TEST_PANE_THREAD_ID='' \
  CODEX_THREAD_ID="$missing_id" PATH="$tmp_root/bin:$PATH" \
  "$repo_root/tmux/bin/codex-tmux-notify" \
  "{\"type\":\"agent-turn-complete\",\"thread-id\":\"$saved_id\"}"
grep -F "set -p -t %origin @codex_pane_thread_id $saved_id" "$tmp_root/tmux.log" >/dev/null

: >"$tmp_root/tmux.log"
TMUX_PANE='%origin' TMUX_TEST_LOG="$tmp_root/tmux.log" \
  TMUX_TEST_PANE_PATH="$tmp_root" TMUX_TEST_PANE_THREAD_ID="$saved_id" \
  CODEX_THREAD_ID="$missing_id" PATH="$tmp_root/bin:$PATH" \
  "$repo_root/tmux/bin/codex-tmux-notify" '{"type":"agent-turn-complete","id":"not-a-thread"}'
test ! -s "$tmp_root/tmux.log"

# A recap notification must not replace the saved thread or any visible state.
TMUX_PANE='%origin' TMUX_TEST_LOG="$tmp_root/tmux.log" \
  TMUX_TEST_PANE_PATH="$tmp_root" TMUX_TEST_PANE_THREAD_ID="$saved_id" \
  PATH="$tmp_root/bin:$PATH" \
  "$repo_root/tmux/bin/codex-tmux-notify" \
  "{\"thread-id\":\"$missing_id\",\"last-assistant-message\":\"recap\"}"
test ! -s "$tmp_root/tmux.log"
CODEX_THREAD_ID='' run_helper ""
grep -F "codex fork $saved_id" "$tmp_root/tmux.log" >/dev/null

# Database failures leave existing state untouched and do not create a database.
: >"$tmp_root/tmux.log"
TMUX_PANE='%origin' TMUX_TEST_LOG="$tmp_root/tmux.log" \
  TMUX_TEST_PANE_PATH="$tmp_root" TMUX_TEST_PANE_THREAD_ID="$saved_id" \
  CODEX_SQLITE_HOME="$tmp_root/absent" PATH="$tmp_root/bin:$PATH" \
  "$repo_root/tmux/bin/codex-tmux-notify" "{\"thread-id\":\"$saved_id\"}"
test ! -s "$tmp_root/tmux.log"
test ! -e "$tmp_root/absent"

# A persisted record alone is insufficient when its rollout has disappeared.
python3 - "$CODEX_HOME/state_5.sqlite" "$saved_id" <<'PY'
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    db.execute('UPDATE threads SET rollout_path = ? WHERE id = ?',
               (sys.argv[1] + '.missing', sys.argv[2]))
PY
TMUX_PANE='%origin' TMUX_TEST_LOG="$tmp_root/tmux.log" \
  TMUX_TEST_PANE_PATH="$tmp_root" TMUX_TEST_PANE_THREAD_ID="$saved_id" \
  PATH="$tmp_root/bin:$PATH" \
  "$repo_root/tmux/bin/codex-tmux-notify" "{\"thread-id\":\"$saved_id\"}"
test ! -s "$tmp_root/tmux.log"

printf 'codex-tmux-fork-current smoke: OK\n'
