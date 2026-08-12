# Language Coach

Language Coach is the `<prefix> + e` English rewrite helper inside this tmux
configuration.

It uses an OpenAI-compatible `/chat/completions` API only. It does not call
`codex exec` or `trans`, and missing API configuration is treated as an error
rather than silently falling back.

## Key Bindings

- `<prefix> + e`: open an editable popup with an input section and optional
  context section. Leave the context section empty when it is not needed.
- `<prefix> + H`: open read-only Language Coach history.

The result copied to the clipboard or tmux buffer is the recommended natural
English sentence.

## Configuration

The real config file lives outside the repository:

```sh
~/.config/tmux-language-rewrite/language.env
```

The repository only includes a copyable template:

```sh
tmux/.env.example
```

Initialize a new machine with:

```sh
mkdir -p ~/.config/tmux-language-rewrite
cp ~/.config/nvim/tmux/.env.example ~/.config/tmux-language-rewrite/language.env
chmod 600 ~/.config/tmux-language-rewrite/language.env
```

Fill the required values:

```sh
export TMUX_LANG_API_BASE_URL="https://api.openai.com/v1"
export TMUX_LANG_API_KEY="..."
export TMUX_LANG_API_MODEL="gpt-5.5"
export TMUX_LANG_API_REASONING_EFFORT="low"
export TMUX_LANG_API_TIMEOUT="30"
```

The script fails directly when the config file, `TMUX_LANG_API_BASE_URL`,
`TMUX_LANG_API_KEY`, or `TMUX_LANG_API_MODEL` is missing.

## Output Model

The API response is expected to produce:

- `EN`: faithful English translation of the input.
- `BEST`: the natural sentence to use.
- `NOTE`: short Chinese explanation of the improvement.
- `TIP`: short grammar or usage tip.
- `CONTEXT`: optional lead-in generated from the editor's context section.

Compatible providers may omit `CONTEXT`; the client treats it as empty. The
other output fields remain required, and malformed responses are reported as
`api_response_invalid`.

When context is supplied, `CONTEXT` is shown before `BEST` in history so the
final wording is easier to interpret.

## History And Status

History is stored locally at:

```sh
~/.tmux-language-history
```

Failures write a non-sensitive reason to:

```sh
~/.tmux-language.log
```

New log rows contain the request ID, start time, elapsed seconds, and the
specific failure. Input text and API keys are not logged in new rows. The file
is kept at mode `600`.

The tmux status line first shows `Language: translating...` or
`Language: translating with context...`; after the API returns, the shared
message slot updates to `BEST: ...`. If requests overlap, only the newest
request may update status, history, clipboard contents, or paste text. Network
timeouts and other transport errors use the existing retry loop.

The clipboard path is:

1. tmux buffer
2. `@clipboard`
3. `pbcopy`
4. `wl-copy`
5. `xclip`
6. `xsel`
7. `win32yank.exe`
8. `clip.exe`

## Related Docs

- tmux entrypoint: [../README.md](../README.md)
- Windows / WSL clipboard: [windows-wsl-clipboard.md](windows-wsl-clipboard.md)
