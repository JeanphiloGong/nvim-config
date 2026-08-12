#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
entry="$repo_root/tmux/bin/tmux-language-context-input"
config="$repo_root/tmux/.tmux.conf"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-language-input.XXXXXX")"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

mkdir -p "$tmp_root/bin"

cat >"$tmp_root/bin/editor" <<'SH'
#!/usr/bin/env bash
cat >"$1" <<'EOF'
[input]
make this clearer
[/input]

[context]
[/context]
EOF
SH

cat >"$tmp_root/bin/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMUX_TEST_LOG"
SH

chmod +x "$tmp_root/bin/editor" "$tmp_root/bin/tmux"

TMUX_TEST_LOG="$tmp_root/tmux.log" \
PATH="$tmp_root/bin:$PATH" \
VISUAL="$tmp_root/bin/editor" \
EDITOR="$tmp_root/bin/editor" \
  "$entry"

grep -F '@tmux_lang_active_request_id lang-' "$tmp_root/tmux.log" >/dev/null
grep -F '@shared_status_msg Language: translating...' "$tmp_root/tmux.log" >/dev/null
grep -F 'TMUX_LANG_CONTEXT=' "$tmp_root/tmux.log" >/dev/null
grep -F 'TMUX_LANG_REQUEST_ID=lang-' "$tmp_root/tmux.log" >/dev/null
grep -F 'TMUX_LANG_ONLY_IF_ACTIVE=1' "$tmp_root/tmux.log" >/dev/null

grep -F 'bind-key e display-popup' "$config" | grep -F 'tmux-language-context-input' >/dev/null
if grep -Eq '^bind-key E ' "$config"; then
  printf 'expected prefix + E to be unbound\n' >&2
  exit 1
fi
test ! -e "$repo_root/tmux/bin/tmux-language-input"

printf 'tmux-language-input smoke: OK\n'
