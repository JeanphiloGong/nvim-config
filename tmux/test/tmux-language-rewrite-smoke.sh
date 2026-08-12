#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
rewrite="$repo_root/tmux/bin/tmux-language-rewrite"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-language-rewrite.XXXXXX")"
server_pid=""

cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_root"
}
trap cleanup EXIT

missing_output="$(
  XDG_CONFIG_HOME="$tmp_root/missing-config" \
  TMUX_LANG_HISTORY_FILE="$tmp_root/missing-history" \
  TMUX_LANG_LOG_FILE="$tmp_root/missing-log" \
  "$rewrite" "make this clearer" 2>&1
)" && {
  printf 'expected missing config to fail\n' >&2
  exit 1
}
printf '%s\n' "$missing_output" | grep -F "missing config" >/dev/null

port_file="$tmp_root/port"
request_file="$tmp_root/request.jsonl"
counter_file="$tmp_root/count"
python3 - "$port_file" "$request_file" "$counter_file" <<'PY' &
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

port_file, request_file, counter_file = sys.argv[1], sys.argv[2], sys.argv[3]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        with open(request_file, "a", encoding="utf-8") as handle:
            handle.write(body)
            handle.write("\n")

        try:
            with open(counter_file, "r", encoding="utf-8") as handle:
                count = int(handle.read().strip() or "0")
        except FileNotFoundError:
            count = 0
        count += 1
        with open(counter_file, "w", encoding="utf-8") as handle:
            handle.write(str(count))

        if self.path != "/v1/chat/completions":
            self.send_response(404)
            self.end_headers()
            return
        if self.headers.get("Authorization") != "Bearer test-key":
            self.send_response(401)
            self.end_headers()
            return

        if count <= 4:
            response = b'{"error":"temporary upstream failure"}'
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)
            return

        if "trigger timeout retry" in body and count == 8:
            time.sleep(0.15)

        content = {
            "original_text": "make this clearer",
            "english_translation": "Make this clearer.",
            "polished_english": "Could you make this clearer?",
            "teacher_note_zh": "Use a polite request.",
            "grammar_tip_zh": "Could you + verb is softer.",
        }
        if "teammate review" in body:
            content["context_line"] = "For teammate review:"
        if "trigger invalid schema" in body:
            content.pop("english_translation")
        payload = {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(content, ensure_ascii=True),
                    }
                }
            ]
        }
        response = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        try:
            self.wfile.write(response)
        except BrokenPipeError:
            pass

    def log_message(self, format, *args):
        return


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_port))
for _ in range(11):
    server.handle_request()
PY
server_pid="$!"

for _ in $(seq 1 50); do
  [ -s "$port_file" ] && break
  sleep 0.1
done
test -s "$port_file"
port="$(cat "$port_file")"

export XDG_CONFIG_HOME="$tmp_root/config"
mkdir -p "$XDG_CONFIG_HOME/tmux-language-rewrite"
cat >"$XDG_CONFIG_HOME/tmux-language-rewrite/language.env" <<EOF
export TMUX_LANG_API_BASE_URL="http://127.0.0.1:$port/v1"
export TMUX_LANG_API_KEY="test-key"
export TMUX_LANG_API_MODEL="gpt-5.5"
export TMUX_LANG_API_REASONING_EFFORT="low"
export TMUX_LANG_API_TIMEOUT="0.05"
EOF
export TMUX_LANG_HISTORY_FILE="$tmp_root/history"
export TMUX_LANG_LOG_FILE="$tmp_root/log"
unset TMUX

"$rewrite" "make this clearer"
TMUX_LANG_CONTEXT="teammate review" "$rewrite" "make this clearer"
invalid_output="$("$rewrite" "trigger invalid schema" 2>&1)" && {
  printf 'expected invalid API response to fail\n' >&2
  exit 1
}
printf '%s\n' "$invalid_output" | grep -F "api_response_invalid" >/dev/null
grep -F "started_at=" "$TMUX_LANG_LOG_FILE" >/dev/null
grep -F "elapsed_s=" "$TMUX_LANG_LOG_FILE" >/dev/null
grep -F "detail=response JSON missed fields: english_translation" "$TMUX_LANG_LOG_FILE" >/dev/null
if grep -F "trigger invalid schema" "$TMUX_LANG_LOG_FILE" >/dev/null; then
  printf 'expected failure log to omit input text\n' >&2
  exit 1
fi
test "$(stat -c '%a' "$TMUX_LANG_LOG_FILE")" = "600"
"$rewrite" "trigger timeout retry"

mkdir -p "$tmp_root/stub-bin"
cat >"$tmp_root/stub-bin/tmux" <<'SH'
#!/usr/bin/env bash
if [ "$*" = "show -gv @tmux_lang_active_request_id" ]; then
  printf 'active-request\n'
  exit 0
fi
printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
SH
chmod +x "$tmp_root/stub-bin/tmux"

TMUX_TEST_LOG="$tmp_root/tmux-actions" \
PATH="$tmp_root/stub-bin:$PATH" \
TMUX_LANG_HISTORY_FILE="$tmp_root/stale-history" \
TMUX_LANG_REQUEST_ID="stale-request" \
TMUX_LANG_ONLY_IF_ACTIVE="1" \
  "$rewrite" "stale request"

TMUX_TEST_LOG="$tmp_root/tmux-actions" \
PATH="$tmp_root/stub-bin:$PATH" \
TMUX_LANG_HISTORY_FILE="$tmp_root/stale-history" \
TMUX_LANG_REQUEST_ID="stale-request" \
TMUX_LANG_ONLY_IF_ACTIVE="1" \
  "$rewrite" "trigger invalid schema" >/dev/null 2>&1 && {
  printf 'expected stale invalid response to fail\n' >&2
  exit 1
}

test ! -e "$tmp_root/stale-history"
test ! -s "$tmp_root/tmux-actions"

grep -F "api" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Make this clearer." "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Could you make this clearer?" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Use a polite request." "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "For teammate review:" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F '"model": "gpt-5.5"' "$request_file" >/dev/null
grep -F '"reasoning_effort": "low"' "$request_file" >/dev/null
grep -F 'teammate review' "$request_file" >/dev/null
test "$(grep -c 'trigger timeout retry' "$request_file")" -eq 2
test "$(wc -l <"$request_file" | tr -d ' ')" -eq 11

printf 'tmux-language-rewrite smoke: OK\n'
