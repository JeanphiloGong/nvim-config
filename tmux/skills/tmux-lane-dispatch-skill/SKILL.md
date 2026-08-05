---
name: tmux-lane-dispatch-skill
description: v0.1.1 - Public fast path for dispatching one task-local lane with minimal preflight, without entering full task lifecycle orchestration.
---

# Tmux Lane Dispatch Skill

## Overview

This role is the thin public entrypoint for quick lane dispatch.

It exists for the common case where the user wants to start one coder,
reviewer, or issue-gate lane without paying the full cost of task lifecycle
orchestration.

## Trigger and Scope

Use this skill when the goal is:

- create one lane quickly
- keep the current pane as the local control point
- stop after the lane pane exists and bare `codex fork` has been dispatched

Do not use this skill when the goal is to manage review, commit, merge-back, or
task lifecycle state over time. In those cases, use
`$tmux-task-orchestrator-skill`.

In scope:

- run `tmux-orch-preflight`
- resolve the current tmux pane/window context
- dispatch one lane through `tmux-dispatch-lane`
- return the resolved pane map and fork status
- leave prompt injection to an explicit `tmux send-keys` step

Out of scope:

- deciding review or commit readiness
- running tests or repo diagnostics beyond preflight
- managing `next_action` across a long-lived task window
- merge-back or project-level handoff

## Required Inputs

- `task_context`

## Optional Inputs

- `role`: default `coder`
- `phase`
- `worktree_path`
- `window_id`
- `orchestrator_pane_id`

## Fixed Defaults

- `entry_mode=dispatch-fast-path`
- `preflight_mode=dispatch`
- `lane_role_default=coder`
- `post_dispatch_policy=stop-after-fork-dispatched`

## Workflow

1. Resolve current `window_id`, `pane_id`, and `worktree_path`.
2. Resolve helper paths first:
   - `config_home="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"`
   - `tmux_bin="$config_home/tmux/bin"`
   - never search the current project repository for `tmux/bin/*`
3. Run `"$tmux_bin/tmux-orch-preflight" --mode dispatch`.
4. If required checks fail, stop and report the blockers.
5. If required checks pass, call `"$tmux_bin/tmux-dispatch-lane"`.
6. Return the created pane id, fork status, and durable-state mode.
7. If the caller wants the lane to start working immediately, inject the prompt
   explicitly with:
   `tmux send-keys -t <pane> -l "$prompt"` -> `Enter` -> `sleep 0.5` -> `Enter`
   Then publish only a short status such as `reviewer prompt sent: %257` via
   `"$tmux_bin/tmux-shared-status"`; do not echo the full prompt body in user-facing
   commentary.
8. Stop. Do not continue into review, commit, or merge logic.

## Guardrails

- Do not expand into full lifecycle orchestration from this role.
- Do not run reviewer or commit logic unless the user explicitly switches to
  `$tmux-task-orchestrator-skill`.
- Do not recreate pane mechanics inline; use `"$tmux_bin/tmux-dispatch-lane"`.
- Treat degraded mode as usable for dispatch only when preflight says
  `can_dispatch_lane=yes`.
- Do not search the current project repository for `tmux/bin/*`; resolve helper
  binaries from `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/tmux/bin`.
- Do not repeat full prompt bodies in commentary or summaries after sending
  them to a pane.
- Do not inline full prompt bodies inside user-visible shell commands such as
  heredocs, `prompt=...`, or long `printf` command strings.
- When a wrapper or manual command calls `codex fork`, the `[SESSION_ID]`
  argument must be `CODEX_SESSION_ID` or `CODEX_THREAD_ID`, not a tmux session
  name such as `tender_back/dev-14`.

## References

- `../tmux-task-lane-bootstrap-skill/SKILL.md`
- `../tmux-task-orchestrator-skill/SKILL.md`

## Output Format

```text
## Dispatch
- role:
- task_context:
- window_id:
- orchestrator_pane:

## Verification
- preflight_required_ready:
- preflight_optional_ready:
- can_dispatch_lane:
- fork_status:

## Pane Map
- orchestrator_pane:
- dispatched_pane:

## Handoff
- next_owner:
- note:
```
