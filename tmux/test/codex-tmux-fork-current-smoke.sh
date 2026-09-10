#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
entry="$repo_root/tmux/bin/codex-tmux-fork-current"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-tmux-fork.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

saved_id="01a00000-0000-7000-8000-000000000001"
missing_id="01a00000-0000-7000-8000-000000000002"

mkdir -p "$tmp_root/bin"

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
      *'@codex_pane_thread_id'*) printf '%s\n' "$TMUX_TEST_PANE_THREAD_ID" ;;
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
grep -F 'set -pu -t %origin @codex_pane_thread_id' "$tmp_root/tmux.log" >/dev/null

printf 'codex-tmux-fork-current smoke: OK\n'
