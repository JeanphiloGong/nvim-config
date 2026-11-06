# Learning Wiki

Completed code explanations and follow-ups become English concept notes in
`~/Documents/Learning Wiki`. Open that folder with Obsidian's **Open folder as
vault**, then start at `Learning.md`. Obsidian builds backlinks and its graph
from the relative Markdown links. No Obsidian plugin, paid service, or desktop
process is needed for generation.

## Daily use

Select code with `Shift+V`, then press `Space a e`. Ask follow-ups with
`Space a a`. After each successful answer is saved, a separate Python process
updates the Wiki in the background. The explanation remains available while
this runs. Press `Space a w` or run `:LearningWikiOpen` to open the index in a
new Neovim tab. On a link's relative path inside `(...)`, use `gf` to follow it
and `Ctrl-o` to return.

The first update uses `gpt-6.1-terra` with reasoning effort `none`, requesting
service tier `fast`. This is an additional API request per changed conversation;
the configured provider has not confirmed Fast processing. It sends the saved
snapshot/conversation and a catalog of concept titles, without reading the rest
of your project. It uses the API-key Responses provider in `$CODEX_HOME` or
`~/.codex`, as the explanation backend does. Python 3.11+ and Linux/WSL are
required. There are no third-party Python packages or agent frameworks.

To change the vault or disable automatic updates, set these before plugin
initialization in your Neovim configuration:

```lua
vim.g.learning_wiki_vault = vim.fn.expand("~/Documents/Learning Wiki")
vim.g.learning_wiki_enabled = false -- Omit this line to enable automatic updates.
```

Disabling or failing a Wiki update does not change the original explanation,
follow-up, or history. Failures produce a Neovim warning; no automatic retry is
made. Retry a completed record or import older completed records explicitly:

```sh
python3 ~/.config/nvim/tools/learning-wiki/wiki.py \
  --vault "$HOME/Documents/Learning Wiki" \
  "/absolute/path/to/completed-explanation.md"
```

Multiple record paths can be supplied. Do not import an explanation that is
still generating or ended with a failed/interrupted answer. The hook only sends
successful completions. Custom provider credentials can be selected with
`--codex-home /path/to/codex-home`. Credentials are not placed in the vault.

## Files and ownership

```text
Learning.md                 Index linking to concepts and conversations
Concepts/<concept-id>.md     One shared page per canonical learning concept
Sources/<record>-<id>.md     Full saved explanation, code snapshot, and concept links
Notes/README.md              A place for your own writing
.learning-wiki/state.json    Source versions, content hashes, and concept catalog
.learning-wiki/lock          Serializes this tool's processes
```

Each concept contains a generated section for each contributing conversation,
linked to that conversation's full source note. Follow-ups replace that source's
section on the same concept page. Other source sections remain. Reusing an
existing concept ID merges conversations onto one page; the model receives the
catalog and is asked to reuse it. Concept selection is model-driven, so related
but differently named concepts can still need human curation.

Write anywhere **outside** `<!-- learning-wiki:...:start -->` / `end` blocks,
or in `Notes/`. Those manual sections are preserved. Text inside managed blocks
is regenerated. Do not rename generated files or edit their delimiters; the
state tracks canonical filenames. Original explanation files stay untouched.
The source copy in the vault keeps the context even if the original code or
record is later moved. Its `file:` link back to the original record is local to
the originating machine; links between vault pages remain relative.

Identical content skips another API call. Older snapshots cannot overwrite a
newer imported version. A process lock covers extraction and writes, and files
are read again after inference so edits made while the request is running are
preserved. Each file is replaced atomically and state is saved last. This is not
a transaction across files or a lock shared with Obsidian; avoid editing a
managed section during an update. After a partial write failure, rerun the
record. Concurrent writers or sync tools need their own coordination.

These are learning notes with evidence, not a record of verified mastery.
Review generated claims against the retained code and explanation.

## Implementation and checks

`wiki.py` parses snapshots, requests strict structured output, validates concept
IDs/relationships, and writes Markdown itself. The model cannot write files or
run tools. The standalone explanation plugin only emits `CodeExplainComplete`;
`lua/plugins/code-explain.lua` owns the asynchronous integration.

```sh
python3 tools/learning-wiki/test_wiki.py
nvim --headless -u NONE -l local/code-explain.nvim/test/code-explain-smoke.lua
nvim --headless -i NONE -n -c 'lua dofile("test/code-explain-config.lua")'
```

Tests use a local HTTP provider, temporary vaults, and an executable double.
They cover canonical IDs, relative links, manual edits during inference,
follow-ups, duplicate/stale snapshots, concurrent imports, failure isolation,
and index navigation without real API requests.

Obsidian [vaults](https://help.obsidian.md/manage-vaults) are ordinary folders.
Its [internal links](https://help.obsidian.md/links) support standard Markdown.
The API request follows the official
[structured output guide](https://developers.openai.com/api/docs/guides/structured-outputs).
Sync and Publish are separate optional Obsidian services; this integration
creates local files and does not configure either service.
