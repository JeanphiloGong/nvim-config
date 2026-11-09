# code-explain.nvim

Explain selected lines beside the source, ask follow-up questions, and keep the
conversation as a local Markdown document. Explanations and follow-up answers
use English and preserve code identifiers.

Initial explanations start with the purpose, inputs, and result, then quote each
declaration, assignment, condition, and return in source order. Each explanation
first connects the statement to the surrounding flow: where its data comes from,
what later consumes it, or what a failure branch prevents. It then teaches syntax,
variable roles, call arguments, and compound expressions where they appear,
followed by an execution example and relevant boundaries. Missing helper details
are qualified without obscuring the role established by the visible caller.
There is no fixed word limit; standalone braces and blank lines do not need
separate entries.
Follow-ups stay focused on the latest question. The prompt includes a complete
teaching example and examples for missing context and a narrow follow-up.
The bundled teaching style lives in `prompts/code-explain.md`. Set `prompt_file`
to use your own file. It is read for each request, so edits apply without
restarting Neovim.

## Installation

Add this directory to your plugin manager. For lazy.nvim, when it is placed
under the Neovim configuration's `local/` directory:

```lua
{
  dir = vim.fn.stdpath("config") .. "/local/code-explain.nvim",
  name = "code-explain.nvim",
  main = "code_explain",
  cmd = { "CodeExplain", "CodeExplainAsk", "CodeExplainHistory", "CodeExplainModel" },
  opts = {},
  keys = {
    { "<leader>ae", ":CodeExplain<cr>", mode = "x", silent = true, desc = "Explain selected code" },
    { "<leader>aa", "<cmd>CodeExplainAsk<cr>", desc = "Ask about code explanation" },
    { "<leader>ah", "<cmd>CodeExplainHistory<cr>", desc = "Code explanation history" },
    { "<leader>am", "<cmd>CodeExplainModel<cr>", desc = "Code explanation model" },
  },
}
```

Without a plugin manager, add this directory to `runtimepath` and call
`require("code_explain").setup()`. No other Neovim configuration is required.
The plugin registers commands; the host configuration owns global keymaps.

## Configuration

`setup()` accepts four optional settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| `model` | `gpt-6.1-terra` | Initial model, before a saved model selection exists |
| `reasoning_effort` | `none` | Initial reasoning effort |
| `codex_home` | `$CODEX_HOME` or `~/.codex` | Directory containing the provider configuration and API-key credentials |
| `prompt_file` | The plugin's `prompts/code-explain.md` | Teaching instructions, loaded on every request |

For example, to use a custom prompt:

```lua
require("code_explain").setup({
  prompt_file = vim.fn.stdpath("config") .. "/my-code-teaching.md",
})
```

Create that file before requesting an explanation. Supply absolute paths for
custom files and directories. Model selections made with `:CodeExplainModel`
take precedence over the initial model settings and survive restarts.

## Workflow

With the example keymaps above:

1. Press `Shift+V`, then `j` / `k` to select the method's lines.
2. Press `<leader>ae` (`Space a e`) to open an explanation in a split.
3. In that document, press `<leader>aa` to enter a follow-up question.
4. Press `q` to close the explanation window. The document stays on disk.
5. Press `<leader>ah` to pick a saved conversation for the current project.
6. Press `<leader>am` to choose a model from the configured provider.

Equivalent commands are `:'<,'>CodeExplain`, `:CodeExplainAsk`,
`:CodeExplainHistory`, and `:CodeExplainModel`. A range such as
`:10,25CodeExplain` also works. Selection is line-based. When creating a window,
the plugin first balances the current tab: more columns than rows opens below,
and more rows than columns opens to the right. When the counts match, a source
window at least twice as wide in columns as it is tall in lines opens to the
right; otherwise it opens below. Floating windows are excluded from the counts,
and new splits are equalized.

New explanations and history reuse the explanation window in the current tab.
An existing window keeps its split direction after resizing. `Ctrl-w h`,
`Ctrl-w j`, `Ctrl-w k`, and `Ctrl-w l` move between the windows.

Text appears and saves as it arrives. Closing the window lets generation
continue; exiting Neovim stops the request and keeps the partial answer with an
interruption notice. Failed or truncated streams also retain their partial text.

## Completion hook

After saving a successful explanation or follow-up, the plugin emits the Neovim
`User` event `CodeExplainComplete`. `event.data` contains the absolute `path`,
the full saved `content` (including its final newline), and a `version` pair
`{ seconds, nanoseconds }` from the saved file's modification time. Use that
snapshot for background work; the file can change when another follow-up starts.
Streaming, failed requests, and interrupted editor shutdown do not emit it.
Consumer errors are reported after the explanation is saved.

The host configuration uses this hook for its optional
[Obsidian learning Wiki](../../tools/learning-wiki/README.md). The standalone
plugin has no Wiki or Obsidian dependency.

## Models and speed

The default is `gpt-6.1-terra` with reasoning effort `none`. Requests explicitly
set `service_tier: "fast"`. These settings belong to the explanation feature.
Existing saved model and effort preferences still apply.

Higher reasoning effort can increase the delay before text appears. Fast mode
does not guarantee that `xhigh` will be faster than `none`. See the
[local measurements](docs/benchmarks.md) for observations and limits.
The answer starts directly after the source snapshot, without an extra
explanation heading, model information, or service tier details. Current tests
returned `default` for both `fast` and its official equivalent, `priority`, so
Fast processing has not been confirmed by the configured provider.

Official [Terra documentation](https://developers.openai.com/api/docs/models/gpt-6.1-terra)
lists `xhigh` support and Fast pricing at twice Standard. Actual billing through
the configured provider must be checked with that provider.

Choose a model with `<leader>am`, or specify it and an optional reasoning effort:

```vim
:CodeExplainModel gpt-6.1-terra none
:CodeExplainModel gpt-6.1-terra xhigh
:CodeExplainModel gpt-6.1-sol low
```

Choosing the configured initial model uses its configured reasoning effort;
another model defaults to `low`.
Use the optional second argument for a different supported effort; `default`
omits the reasoning option from the API request. The provider validates model
and effort availability.
Selections persist in `stdpath("data")/code-explain/model.json`.

## Storage and context

Documents live under `stdpath("data")/code-explain/`, grouped by project, outside
the source repository. Each includes the source path, selected line numbers,
creation time, and a snapshot taken directly from the buffer, including unsaved
changes. Model and service settings are omitted from the explanation document.
Closing a window or restarting Neovim does not delete a document. Remove
unwanted records explicitly from that directory.

Each follow-up sends the original snapshot and saved conversation again.
Reopening an existing record, including one made with the earlier Codex backend,
restores that context. The snapshot remains the reference if the source changes.
Long conversations send more context on each follow-up.

The fast path sends the selection and conversation directly to the model. It
does not inspect the project or run tools. Include relevant imports and type
definitions in the selection when needed; missing context is stated explicitly.

## Requirements and implementation

Use Neovim with `vim.system` and `vim.fs.root` (verified on Neovim 0.12.5),
Python 3.11+ on `PATH`, and a Responses API provider configured in
`codex_home/config.toml`. The helper reads the
provider's `env_key` environment variable (default `OPENAI_API_KEY`) or the
`OPENAI_API_KEY` field of that Codex home's `auth.json`. ChatGPT OAuth tokens
alone cannot authenticate this direct API path. Credentials stay in the Python
process and are never passed through a shell command or written into records.

`lua/code_explain.lua` handles the windows, Markdown, history, and model picker.
`prompts/code-explain.md` contains the teaching instructions and examples.
`scripts/code-explain.py` uses Python's standard library to stream Responses API
text events, following the official [streaming reference](https://developers.openai.com/api/docs/guides/streaming-responses).
There is no agent-framework dependency. The helper validates completion at the
API boundary; the Lua view updates at most every 100 ms without moving the
reader's cursor. No Codex session files are created by explanation requests.

## Verification

From this plugin directory:

```sh
python3 test/code-explain-api.py
nvim --headless -u NONE -l test/code-explain-smoke.lua
```

These checks use a local HTTP server, an executable double, and temporary data.
They verify streaming before completion, request parameters, provider errors,
consumer-defined mappings, snapshots, saving, follow-ups, history, model
persistence, setup options, prompt edits, and editor shutdown. They need no
real credentials, network connection, lazy.nvim, or a surrounding Neovim configuration.

## Layout

```text
lua/code_explain.lua        Windows, records, commands, and request orchestration
scripts/code-explain.py     Provider configuration and Responses API streaming
prompts/code-explain.md     Teaching instructions and examples
test/                      Standalone tests
docs/benchmarks.md          Measured latency and comparison limits
```
