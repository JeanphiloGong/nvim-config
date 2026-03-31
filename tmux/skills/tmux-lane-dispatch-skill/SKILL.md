---
name: tmux-lane-dispatch-skill
description: v0.1.0 - Public fast path for dispatching one task-local lane with minimal preflight, without entering full task lifecycle orchestration.
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
2. Run `tmux/bin/tmux-orch-preflight --mode dispatch`.
3. If required checks fail, stop and report the blockers.
4. If required checks pass, call `tmux/bin/tmux-dispatch-lane`.
5. Return the created pane id, fork status, and durable-state mode.
6. If the caller wants the lane to start working immediately, inject the prompt
   explicitly with:
   `tmux send-keys -t <pane> -l "$prompt"` -> `Enter` -> `sleep 0.2` -> `Enter`
7. Stop. Do not continue into review, commit, or merge logic.

## Guardrails

- Do not expand into full lifecycle orchestration from this role.
- Do not run reviewer or commit logic unless the user explicitly switches to
  `$tmux-task-orchestrator-skill`.
- Do not recreate pane mechanics inline; use `tmux/bin/tmux-dispatch-lane`.
- Treat degraded mode as usable for dispatch only when preflight says
  `can_dispatch_lane=yes`.

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
