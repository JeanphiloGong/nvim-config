# AGENTS.md (Project Rules)
## Overview
- Project: nvim-config
- Purpose: A portable, one-command Neovim configuration for multiple devices.
- Tech stack: LazyVim, Lua.
- Key paths: init.lua, lua/, docs/, test/, tmux/, lazy-lock.json, README.md.
- Collaboration: Single-agent; the owner is the sole approver.

## Core Principles
1) Portability comes first.
2) Keep changes minimal and intentional.
3) Prefer stable, predictable behavior over novelty.
4) Document non-obvious behavior changes.
5) Keep startup reliable and clean.

## Domain Philosophies (Master-Level)
### Engineering
- Goal: A reliable, maintainable config that boots cleanly anywhere.
- Constraints: No machine-specific assumptions or fragile startup ordering.
- Evidence: Clean startup on a fresh machine; no errors in :messages.
- Failure Cost: Editor becomes unusable or inconsistent across devices.
- Tradeoffs: Prefer simplicity and clarity over complex customization.
- Non-negotiables: The config must load without manual fixes after clone.

### Product (Developer Experience)
- Goal: Fast, consistent editing workflow across machines.
- Constraints: Avoid friction in install and daily use.
- Evidence: One-command install and :Lazy sync complete without errors.
- Failure Cost: Slow onboarding or broken workflows.
- Tradeoffs: Favor stable defaults over experimental features.
- Non-negotiables: Core workflows remain discoverable and stable.

## Product & Project Standards
- Goals: One-command setup; consistent behavior across devices.
- Success signals: Fresh clone boots without errors; no per-machine edits required.
- Scope: Repository-local Neovim config and supporting docs.
- Release: Normal release; no special gates.

## 12 Golden Rules (Why / How / Check)
1) Keep the config portable.
   - Why: The project exists to work across devices.
   - How: Avoid absolute paths and machine-specific settings.
   - Check: No device-specific paths added in diffs.
2) Follow LazyVim conventions.
   - Why: Consistency reduces conflicts and surprises.
   - How: Use the standard plugin spec layout and patterns.
   - Check: New additions match existing LazyVim structure.
3) Make changes as small as possible.
   - Why: Smaller diffs reduce breakage risk.
   - How: Limit edits to the smallest necessary area.
   - Check: Diffs are scoped to the requested change.
4) Document behavior changes.
   - Why: Portability requires shared understanding.
   - How: Update docs when workflows or keymaps change.
   - Check: docs/ reflects new behavior.
5) Keep startup stable.
   - Why: Broken startup blocks all work.
   - How: Avoid heavy sync or blocking work on startup.
   - Check: No new startup errors introduced.
6) Avoid plugin sprawl.
   - Why: Extra plugins increase maintenance cost.
   - How: Add only when there is a clear need.
   - Check: Each plugin has a stated purpose.
7) Keep keymaps consistent.
   - Why: Consistency improves muscle memory.
   - How: Follow existing leader prefixes and patterns.
   - Check: No conflicting mappings are added.
8) Treat the lockfile as a contract.
   - Why: Reproducibility across machines.
   - How: Update lazy-lock.json only when plugin versions change.
   - Check: Lockfile changes correspond to plugin updates.
9) Do not commit secrets.
   - Why: Security and portability.
   - How: Keep tokens and private keys out of config.
   - Check: No secrets in diffs.
10) Keep files ASCII unless required.
   - Why: Portability and tooling compatibility.
   - How: Use ASCII for new content by default.
   - Check: New files are ASCII-only.
11) Keep docs accurate.
   - Why: Users rely on docs for setup.
   - How: Update README or docs when instructions change.
   - Check: Docs match current behavior.
12) Require explicit owner request for code/config edits.
   - Why: Single-owner control of changes.
   - How: Only edit code/config when asked.
   - Check: Changes map to a clear owner request.

## Scope Boundaries
- In scope: All paths in this repository.
- Forbidden: None specified.
- High-risk areas: None specified.

## Permission Model
- Docs can be edited when requested.
- Code and config changes require explicit owner request.
- No forbidden paths; repo-wide edits are allowed with approval.

## Execution Rules
- Default to proposing changes before writing files.
- Keep diffs minimal and scoped to the request.
- Avoid destructive commands and history rewrites.
- Note any assumptions or missing information.

## Quality Bar
- Tests: Not required.
- Evidence of done: Requested changes applied; no obvious startup errors if checked.

## Decision & Accountability
- Decision owner: Single owner.
- Decision log: Git commit messages (no separate log defined).
- Risk log: None specified; if needed, record in this file.

## Risks & Open Questions
- Risks: None specified.
- Open questions: None.
