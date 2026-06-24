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
python3 - "$port_file" "$request_file" <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port_file, request_file = sys.argv[1], sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        with open(request_file, "a", encoding="utf-8") as handle:
            handle.write(body)
            handle.write("\n")

        if self.path != "/v1/chat/completions":
            self.send_response(404)
            self.end_headers()
            return
        if self.headers.get("Authorization") != "Bearer test-key":
            self.send_response(401)
            self.end_headers()
            return

        content = {
            "original_text": "make this clearer",
            "english_translation": "Make this clearer.",
            "polished_english": "Could you make this clearer?",
            "teacher_note_zh": "Use a polite request.",
            "grammar_tip_zh": "Could you + verb is softer.",
            "context_line": "",
        }
        if "teammate review" in body:
            content["context_line"] = "For teammate review:"
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
        self.wfile.write(response)

    def log_message(self, format, *args):
        return


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_port))
server.handle_request()
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
export TMUX_LANG_API_TIMEOUT="5"
EOF
export TMUX_LANG_HISTORY_FILE="$tmp_root/history"
export TMUX_LANG_LOG_FILE="$tmp_root/log"
unset TMUX

"$rewrite" "make this clearer"
TMUX_LANG_CONTEXT="teammate review" "$rewrite" "make this clearer"

grep -F "api" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Make this clearer." "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Could you make this clearer?" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "Use a polite request." "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F "For teammate review:" "$TMUX_LANG_HISTORY_FILE" >/dev/null
grep -F '"model": "gpt-5.5"' "$request_file" >/dev/null
grep -F '"reasoning_effort": "low"' "$request_file" >/dev/null
grep -F 'teammate review' "$request_file" >/dev/null

printf 'tmux-language-rewrite smoke: OK\n'
