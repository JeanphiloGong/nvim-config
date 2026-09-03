# Linux And WSL Environment Matrix

## Source Of Truth

Use this matrix after rereading the checked-out configuration. It covers Linux
and WSL hosts. The current repository requires Neovim 0.11 or newer and
includes:

- Lazy.nvim plugin bootstrap from `init.lua`.
- Native-build plugins that require `make` and a C compiler.
- Telescope search backed by `rg` and a file finder (`fd` or `fdfind`).
- Node-based Markdown, Prettier, Mermaid, and Mason packages.
- Mason LSPs for Python, Svelte, TypeScript, Go, C/C++, Rust, Solidity, and
  C#.
- `csharp_ls@0.15.0`, which requires .NET SDK 8 on this configuration.
- tmux helpers that use Bash, Git, tmux, jq, awk, ps, and procps tools.

Recheck `lua/plugins/*.lua` and `tmux/bin/` before acting. This reference is a
bootstrap checklist, not permission to overwrite a workstation.

## Version Gates

| Component | Required state | Check |
| --- | --- | --- |
| Neovim | 0.11 or newer | `nvim --version` |
| Node | Current supported LTS | `node --version` |
| Package client | npm and Yarn available | `npm --version`, `yarn --version` |
| .NET | SDK 8.x | `dotnet --list-sdks` |
| Rust | `cargo` and `rustc` available | `cargo --version`, `rustc --version` |
| tmux | Supports the checked-out popup and status configuration | `tmux -V` |
| Build tools | `make` plus a C compiler | `make --version`, `cc --version` |
| Search tools | `rg` plus `fd` or `fdfind` | `rg --version`, `fd --version` or `fdfind --version` |
| tmux state | `jq`, `awk`, `ps`, `free` | command checks |

## Baseline Packages

Install only after the user approves the plan. Package availability and version
numbers differ by release, so inspect the result after installation.

| Distro family | Baseline package names |
| --- | --- |
| Debian / Ubuntu | `bash ca-certificates curl git build-essential make unzip tar gzip ripgrep fd-find tmux jq procps python3 python3-venv golang-go rustc cargo clang nodejs npm` |
| Fedora / RHEL | `bash ca-certificates curl git gcc gcc-c++ make unzip tar gzip ripgrep fd-find tmux jq procps-ng python3 go rust cargo clang nodejs npm` |
| Arch | `base-devel bash ca-certificates curl git unzip tar gzip ripgrep fd tmux jq procps-ng python go rust cargo clang nodejs npm` |

On Debian and Ubuntu, `fd-find` may expose `fdfind` instead of `fd`; record
that result and let the configured tool select a supported finder. Do not add a
wrapper or replace a system binary merely to normalize the name.

For Arch, a synchronized system update is part of normal package management;
state that impact and get approval before running it. For other distributions,
do not run a full system upgrade just to provision this repository.

## Neovim, Node, And .NET

1. Install the distro package only when it meets the version gate.
2. If Neovim is older than 0.11, resolve the current official Neovim release
   for the detected architecture, verify its source and checksum, and install
   it in a user-owned or explicitly approved system location.
3. If the distribution Node package is not a current supported LTS, use an
   approved maintained Node source, then verify `node`, `npm`, and `yarn`.
4. Enable Corepack when it is available. Otherwise, install Yarn only after
   approving its global npm mutation.
5. Install .NET SDK 8 using the current official Microsoft instructions for
   the detected distribution. Do not replace it with a newer SDK just because
   it is easier to obtain: the C# LSP version in `backend.lua` is deliberately
   pinned for .NET 8 compatibility.

## Repository Links

The tmux configuration refers to `~/.config/nvim`, so use that standard path.

| Target | Desired result | Conflict handling |
| --- | --- | --- |
| `~/.config/nvim` | This repository or a symlink to it | Stop if it already exists and is not the intended clone. |
| `~/.tmux.conf` | Symlink to the detected Linux or WSL tmux profile | Stop if it already exists and differs. |
| `~/.tmux/plugins/tpm` | TPM clone | Clone only when absent. |

If the user requires a nonstandard `XDG_CONFIG_HOME`, report that the checked-
out tmux configuration has standard-path assumptions and ask whether to change
the configuration in a separate task.

## Plugin And Tool Bootstrap

Run plugin installation from an interactive Neovim instance:

1. Start `nvim`.
2. Run `:Lazy sync` and wait for all work to finish.
3. Restart `nvim` and inspect `:Mason` until the configured packages are
   installed.
4. Run `:checkhealth` and address blockers before declaring success.

Avoid a timed headless command that exits while Lazy or Mason is still working.

Install selected external Node tools after Node and Yarn are ready:

```sh
npm install -g @mermaid-js/mermaid-language-server @mermaid-js/mermaid-cli
```

`live-server` is optional and only needed for the README's static Mermaid
preview workflow.

## Tmux Configuration Contract

The tmux configuration is part of the bootstrap contract, not merely a package
dependency. The selected profile always assumes the repository is available at
the standard `~/.config/nvim` path.

1. Detect WSL before choosing a profile. Use `tmux/.tmux.conf.wsl` when
   `WSL_DISTRO_NAME` is set or `/proc/version` identifies Microsoft/WSL; use
   `tmux/.tmux.conf` for other Linux hosts.
2. Resolve any existing `~/.tmux.conf`. Create its symlink only when absent;
   leave it unchanged when it resolves to the selected profile, and stop on
   every other existing file or link.
3. Clone TPM only when `~/.tmux/plugins/tpm` is absent, then start tmux, source
   `~/.tmux.conf`, install plugins, and source the configuration again:

```sh
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
tmux start-server
tmux source-file "$HOME/.tmux.conf"
"$HOME/.tmux/plugins/tpm/bin/install_plugins"
tmux source-file "$HOME/.tmux.conf"
```

Both profiles set `C-a` as the prefix; include TPM with sensible, themepack,
vim-tmux-navigator, yank, resurrect, and continuum; preserve split panes in
the current directory; and provide a two-line Git/CPU/RAM/time status layout.
They also configure the Codex menu/jump/fork keys, popup shell, Git branch
copy, and Language Coach entry/history keys.

The profiles intentionally differ in their clipboard behavior and Codex menu
key. Linux uses OSC 52 and retains copy mode after `y`, with Codex menu on
`prefix + M`. WSL uses `win32yank.exe -i --crlf` after `y`, with Codex menu on
`prefix + C`. Install and test `win32yank.exe` only for the WSL profile. Never
combine the profiles or carry the WSL clipboard command to a normal Linux host.

The optional Codex notification hook needs an authenticated `codex` command, a
user-local `~/.local/bin/codex-tmux-notify` link, and a deliberate edit to
`~/.codex/config.toml`. The fork bindings require a real Codex session or
thread ID, normally supplied by `CODEX_SESSION_ID` or `CODEX_THREAD_ID`; a tmux
session, window, or pane ID is not valid. Do not alter the Codex configuration
unless the user requests this integration.

Language Coach is optional. Its environment file belongs outside the repository
at `~/.config/tmux-language-rewrite/language.env`, must be mode `600`, and
requires the user to enter their own API credentials.

## Smoke Checks

Use evidence from these checks in the final report:

```sh
nvim --version
tmux -V
jq --version
dotnet --list-sdks
mermaid-language-server --help
mmdc --version
```

For C#, create or open a minimal project containing a `.csproj`, then use
`:LspInfo` to confirm `csharp_ls` attached. Confirm Mason reports
`csharp-language-server` version 0.15.0. For tmux, record the selected profile,
source the configuration, verify the `C-a` prefix, two-line status, pane border
labels, TPM plugin loading, and the profile-specific copy binding before trying
optional Codex or Language Coach workflows.
