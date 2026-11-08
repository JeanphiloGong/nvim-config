# Personal notes in Neovim

`obsidian-nvim/obsidian.nvim` is pinned to `v3.16.10` and uses the entire
`~/Documents/Obsidian Vault` workspace, including personal notes and
`04-CodeWiki`. It loads on Markdown files, its command, or a note keymap.
The existing Telescope picker provides note lists, previews and text search.
Obsidian desktop is optional; Neovim and `ripgrep` provide these workflows.

| Key | Action | Command |
| --- | --- | --- |
| `Space n f` | Find a note by name | `:Obsidian quick_switch` |
| `Space n s` | Search note contents | `:Obsidian search` |
| `Space n n` | Create a note in `00-收件箱` | `:Obsidian new` |
| `Space n d` | Open or create today's `01-日记/YYYY-MM-DD.md` | `:Obsidian today` |
| `Space n b` | Find references to the current note | `:Obsidian backlinks` |
| `Space n e` | Browse the vault directory in a new tab | |
| `Space n h` | Open `Home.md` in a new tab | |

Use `Space n e` from any project to browse the vault's folders. Both it and
`Space n h` give the new tab the vault as its working directory, so `Space e`
there opens the notes tree. The original code tab keeps its project directory
and unsaved buffers. Use `gt` or `gT` to switch tabs.
The equivalent directory command is:

```vim
:tabnew | Neotree filesystem left dir=~/Documents/Obsidian\ Vault reveal=false
```

Enter a title when prompted for a new note. Filenames use the built-in UTF-8
title preset, so Chinese titles stay readable and repeated names receive a
numeric suffix. New notes start blank. Daily notes reuse the configured date
file, matching the `obsidian-notes` skill's journal location.

Inside a note, `[[` triggers note-reference completion through the plugin's
in-process LSP and the existing `nvim-cmp` LSP source. Press `Enter` on a link
to follow it. Standard Markdown links, including generated code Wiki links,
are also supported. Save a new reference before checking its backlinks.
The backlinks setting searches the note even when the cursor is on its title,
instead of restricting the results to references to that heading.

The config keeps raw Markdown visible and disables automatic frontmatter
management. Existing handwritten sections and generated Wiki blocks are not
rewritten by the plugin's metadata handling. Code explanations still enter
`04-CodeWiki` through their existing completion hook; `Space a w` opens that
code index.

The vault directory is created on first plugin use when missing. On a new
device, restore your existing notes (including hidden Wiki state) as described
in the [learning Wiki guide](../../tools/learning-wiki/README.md).
The configuration does not synchronize notes or install Obsidian desktop;
`Home.md` can be restored or written as your own personal index.

The setup follows the pinned release's official documentation:

- [Commands and requirements](https://github.com/obsidian-nvim/obsidian.nvim/blob/v3.16.10/README.md)
- [Readable note filenames](https://github.com/obsidian-nvim/obsidian.nvim/blob/v3.16.10/docs/Note.md#note-id-presets)
- [Daily notes](https://github.com/obsidian-nvim/obsidian.nvim/blob/v3.16.10/docs/Daily-Notes.md)
- [Frontmatter settings](https://github.com/obsidian-nvim/obsidian.nvim/blob/v3.16.10/docs/Frontmatter.md#disabling-frontmatter)

Verification with a temporary vault:

```sh
nvim --headless -i NONE -n -c 'lua dofile("test/obsidian-config.lua")'
```
