---
name: nvim-machine-bootstrap-skill
description: "v0.1.0 - Bootstrap this Neovim and tmux workspace on a fresh Linux or WSL machine, including dependency checks, profile-aware configuration links, plugin setup, and verification. Use when a user clones this repository on a new Linux or WSL machine or asks to repair a missing local development dependency."
---

# Nvim Machine Bootstrap Skill

## Overview

Turn a clean Linux or WSL clone of this repository into the maintained Neovim
and tmux workstation without overwriting an existing user configuration or
silently weakening version requirements. The repository configuration is the
source of truth; this skill verifies it before making machine changes.

## When to Use

- A user has cloned this repository on a new Linux or WSL machine and wants the
  full editor and tmux environment ready to use.
- Neovim starts with missing plugins, LSPs, tmux plugins, or required external
  tools after a clone.
- A user asks which host dependencies this repository requires before setup.

**When NOT to use:** a one-off Neovim plugin change, a project-specific
language toolchain unrelated to this repository, macOS or native Windows
setup, or replacing an existing Neovim configuration without explicit
approval.

## Scope and Inputs

The supported target is Linux on Debian/Ubuntu, Fedora/RHEL, or Arch, including
WSL distributions, using the standard `~/.config/nvim` location. Read
`references/linux-environment-matrix.md` for the current dependency matrix and
distribution-specific package guidance.

Before changing the machine, collect:

- repository root and current Git state;
- distro, architecture, shell, WSL state, and whether the session can use
  `sudo`;
- installed versions of Neovim, tmux, Node, .NET, and the required commands;
- whether `~/.config/nvim` or `~/.tmux.conf` already exists;
- the selected tmux profile: `tmux/.tmux.conf` on Linux or
  `tmux/.tmux.conf.wsl` on WSL;
- whether the user wants optional Mermaid, Codex/tmux integration, and
  Language Coach setup.

Do not guess a Git identity, an API key, a Codex login, or a replacement for an
existing configuration.

## Operating Loop

1. Read the repository contract.
   - Read `AGENTS.md`, `README.md`, `lua/plugins/*.lua`, both checked-out tmux
     profiles, and the Linux environment matrix.
   - Derive the required LSPs and external commands from the checked-out
     configuration rather than from an old setup report.
2. Inspect the host without changing it.
   - Identify the Linux distribution from `/etc/os-release`, the architecture
     from `uname -m`, and WSL from `WSL_DISTRO_NAME` or `/proc/version`.
   - Require Neovim 0.11 or newer, a current Node LTS, tmux, build tools,
     Git, search tools, archives, and .NET SDK 8 for the configured C# LSP.
3. Present one concrete setup plan.
   - Separate required packages, optional integrations, configuration links,
     and user-owned secret or login steps.
   - State every `sudo`, global package installation, network clone/download,
     symlink, and configuration-file mutation before performing it.
   - Get confirmation when the request did not already authorize those machine
     changes.
4. Install the required host dependencies.
   - Use the package guidance for the detected distribution.
   - If the package manager cannot provide Neovim 0.11 or a current Node LTS,
     use the current official upstream installation instructions after
     confirming the download source and architecture.
   - Install .NET SDK 8 before allowing Mason to install `csharp_ls@0.15.0`.
5. Link the repository safely.
   - If the clone is already `~/.config/nvim`, leave it in place.
   - Otherwise create `~/.config/nvim` as a symlink only when the destination
     is absent. Stop and ask if it already exists or is not the same target.
   - Select `tmux/.tmux.conf.wsl` only on WSL; otherwise select
     `tmux/.tmux.conf`. Record the selected profile before linking it to
     `~/.tmux.conf`.
   - Create that tmux symlink only when the destination is absent. If the
     existing target does not resolve to the selected tracked profile, stop and
     ask. The tmux configuration expects the standard Neovim path.
6. Bootstrap editor and tmux content.
   - Start Neovim interactively, run `:Lazy sync`, wait for it to finish, then
     restart Neovim.
   - Let the non-headless Mason setup install the configured LSPs. Use `:Mason`
     to inspect and retry an individual package only after the initial pass.
   - Install the external Mermaid tools when that integration is selected.
   - Clone `tmux-plugins/tpm` into `~/.tmux/plugins/tpm` only when it is
     absent. Start the tmux server, source the selected `~/.tmux.conf`, run
     `~/.tmux/plugins/tpm/bin/install_plugins`, then source the config again.
7. Configure optional user-owned integrations separately.
   - Codex/tmux notifications require an installed and authenticated Codex CLI
     plus an explicit edit to the user's Codex configuration.
   - The `f` and `F` bindings only fork a real persisted Codex thread ID from
     `CODEX_THREAD_ID` or the pane's validated notification cache; do not use
     `CODEX_SESSION_ID`, a tmux pane, window, or session name as a fallback.
   - Language Coach requires the user to fill its external environment file;
     never place an API key in this repository or print it in output.
8. Verify the finished workstation and report any deferred items.
   - Run the verification checklist below and distinguish a working baseline
     from optional integrations the user chose not to configure.

## Decision Points

- If the host is not a supported Linux distribution, stop after reporting the
  discovered state. Do not apply Linux package commands to another platform.
- If `WSL_DISTRO_NAME` is set or `/proc/version` identifies Microsoft/WSL, use
  only `tmux/.tmux.conf.wsl`; otherwise use only `tmux/.tmux.conf`. Never merge
  the two profiles or install Windows-only clipboard tools on Linux.
- If `~/.config/nvim` or `~/.tmux.conf` exists and is not this clone's intended
  target, stop before overwriting, moving, or unlinking it.
- If a package manager provides an older Neovim, do not accept it merely
  because `nvim` exists. Install an official 0.11+ build and verify its path.
- If .NET SDK 8 is unavailable, stop before Mason's C# installation and report
  that the pinned `csharp_ls@0.15.0` needs that SDK. Do not silently substitute
  a different LSP or SDK.
- If a plugin or Mason installation needs time, keep its owning Neovim session
  open until completion. Do not terminate it with an arbitrary timed
  headless command.
- If optional integrations require credentials or account login, create only
  their non-secret local structure and leave credential entry to the user.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "The README package list is enough." | Plugin specs and tmux scripts are the current dependency contract; inspect them before installing. |
| "I can replace an existing config to finish quickly." | A workstation configuration is user data. Stop on a target conflict and ask. |
| "Any Neovim or .NET version will work." | This config uses Neovim 0.11 APIs and its C# LSP is pinned for .NET 8. |
| "A short headless wait proves Mason installed." | It can interrupt asynchronous downloads and create a false failure. Wait for completion or use the package's completion signal. |
| "Optional API features can use placeholder credentials." | Placeholders create broken flows and encourage secrets in the repository. Leave user-owned credentials unset. |
| "The Linux and WSL tmux files are interchangeable." | Their clipboard integration and Codex menu bindings differ; link exactly one profile based on the detected host. |

## Red Flags

- The repository was linked over an existing directory or `.tmux.conf`.
- `nvim --version` is below 0.11, but setup continues anyway.
- Mason packages are claimed installed without opening `:Mason` or checking
  the executable and LSP state.
- A command pipes an unverified remote script into a shell.
- A skill action modifies `lazy-lock.json`, a user Git config, or a secret file
  without a direct reason and user approval.
- tmux is declared ready without recording the selected profile, sourcing it,
  and checking TPM plugin installation.

## Verification

- [ ] The repository is the intended `~/.config/nvim` target, with no existing
      configuration overwritten.
- [ ] `nvim --version` reports 0.11 or newer and Neovim starts without startup
      errors.
- [ ] `git`, `curl`, build tools, `rg`, Node, Yarn, Python, Go, Rust, tmux,
      `jq`, and archive tools satisfy the matrix checks.
- [ ] .NET SDK 8 is present and Mason reports all configured LSP packages,
      including `csharp-language-server` version 0.15.0, as installed.
- [ ] A minimal `.csproj` opens with `csharp_ls` attached; other selected
      language integrations have an equivalent smoke check.
- [ ] `:Lazy sync` completes, and the selected Mermaid commands are available.
- [ ] The recorded tmux profile matches the detected host and `~/.tmux.conf`
      resolves to its checked-out path.
- [ ] `tmux show-options -gv prefix` reports `C-a`,
      `tmux show-options -gv status` reports `2`, and
      `tmux show-options -gv pane-border-status` reports `top` after the
      selected config is sourced.
- [ ] TPM plugins install, including `tmux-continuum`, and
      `tmux source-file ~/.tmux.conf` succeeds.
- [ ] The selected copy-mode `y` binding uses OSC 52 without leaving copy mode
      on both Linux and WSL.
- [ ] The selected profile retains the configured Git/status layout, Codex
      bindings, popup shell, and Language Coach bindings. Codex notifications
      and Language Coach credentials remain optional user-owned setup.
- [ ] Optional Codex and Language Coach steps are either verified or explicitly
      recorded as deferred because they require user credentials or login.

## Output Format

```text
## Host Inventory
- distro:
- architecture:
- tmux profile:
- Neovim:
- configuration target:

## Approved Changes
- system packages:
- links:
- plugin and LSP initialization:
- optional integrations:

## Verification
- Neovim:
- Mason and LSPs:
- tmux and TPM:
- deferred user-owned steps:

## Blockers
- none, or exact next action:
```

## Guardrails

- Never overwrite, delete, or move an existing configuration target without
  explicit user approval.
- Do not use unverified `curl | sh` installers or invent package names,
  versions, or host-specific paths.
- Do not create Git identity, API credentials, Codex authentication, or secret
  files on the user's behalf.
- Do not treat external tools as installed until their executable and the
  dependent Neovim or tmux workflow are both verified.
- Keep machine state outside this repository except for the intended symlinks;
  do not add generated plugin state or host files to Git.
