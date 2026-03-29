---
name: project-window-orchestrator-skill
description: v0.2.0 - Public project-level tmux orchestration entry that coordinates multiple task windows and worktrees, decides sequencing across tasks, and hands task-local lifecycle ownership to task-window orchestrators.
---

# Project Window Orchestrator Skill

## Trigger and Scope

Use this skill as the public orchestration entry for tracked tmux-based work
that spans multiple tasks, multiple worktrees, or multiple tmux windows.

This skill is project-scoped. It owns:

- deciding which task window should exist
- deciding which task window should move next
- keeping project phase, dependencies, blockers, and review/merge order visible
- creating new task windows through a bootstrap reference flow
- handing each selected task window to `task-window-orchestrator-skill`

This skill does not perform code implementation itself.

In scope:

- manage multiple task windows as one tracked project surface
- decide whether to create, resume, pause, or complete a task window
- keep project-wide sequencing and dependencies visible
- register and refresh project/task-window state in `tmux-orch` when that
  layer exists
- hand off task-local execution responsibility to
  `task-window-orchestrator-skill`

Out of scope:

- direct code implementation
- per-pane `tmux split-window` mechanics
- coder/reviewer/issue-gate lane work itself
- replacing tmux runtime routing with JSON state

## Core Purpose

- Treat the project as the durable coordination unit.
- Keep one task per task window and one worktree per task window.
- Separate project scheduling from task-local execution control.
- Keep bootstrap and pane layout as subordinate capabilities, not public roles.
- Ensure the public orchestration entry stays non-coding and control-plane only.

## Required Inputs

- `project_context`: concise statement of the project goal or current delivery
  objective

## Optional Inputs

- `repo_root`: current repository root when a new task worktree may be needed
- `project_phase`: current project-level phase when already known
- `task_summary`: target task statement when focusing one task window
- `window_dependency_hint`: optional dependency note between task windows

## Optional Environment Inputs

- `TMUX`
- `CODEX_SESSION_ID`
- `CODEX_THREAD_ID`
- `TMUX_ORCH_ROOT`

## Fixed Defaults

- `project_entry_policy=public-default`
- `window_policy=one-task-one-window`
- `bootstrap_policy=reference-driven`
- `task_local_policy=delegate-task-window-orchestrator`
- `execution_mode=coordination-only`
- `writer_policy=lanes-only`

## Coordination Model

Project-scoped ownership:

- project objective
- project phase
- active task-window set
- dependency and blocker interpretation
- which task window needs action next
- when a task window is ready for review, commit, merge, or closure

Task-scoped ownership delegated out:

- `task-window-orchestrator-skill` owns one task window from local confirmation
  through commit/merge handoff
- worktree creation and first-window creation use the bootstrap reference in
  `references/worktree-bootstrap.md`

## External State Contract

When `tmux-orch` exists, this skill should:

- initialize or reuse the orchestration state root
- register or refresh task-window snapshots
- keep project phase, window status, blockers, and dependencies visible
- treat tmux runtime state as the live routing truth
- let each task-window orchestrator own task-local pane state and handoffs

State-root discipline:

- prefer the session-scoped default root
  `${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/<session_slug>}`
- derive `<session_slug>` from the current tmux session name instead of
  inventing an ad-hoc path
- do not silently write orchestration state to a second root such as
  `/tmp/tmux-orch` unless that override is intentional and propagated to every
  downstream step

Reference:

- `docs/tmux-orch-state-contract.md`

## Guardrails

- Do not write production code from this skill.
- Do not let bootstrap become the public entry; bootstrap is an internal
  capability documented as a reference.
- Do not micromanage pane layout from the project role unless task-local
  orchestration has explicitly failed and ownership is reassigned.
- Do not claim project-wide shared durable state if the current `tmux-orch`
  deployment is still Phase A session-scoped only.

## Recommended Task Sequence

1. enter `project-window-orchestrator-skill`
2. inspect current project windows, blockers, dependencies, and merge order
3. if a new task window is needed, use `references/worktree-bootstrap.md`
4. hand the chosen task window to `task-window-orchestrator-skill`
5. keep coordinating handoffs and status across task windows until the project
   delivery slice is complete

## Workflow

1. Confirm the current coordination context:
   - current repo root when relevant
   - current tmux session/window
   - existing tracked task windows
2. Inspect current project state:
   - active windows
   - blocked windows
   - review-ready windows
   - merge-ready windows
   - dependency constraints between windows
3. If `tmux-orch` exists, initialize or reuse the state root and refresh known
   window records.
4. Decide whether the next action is:
   - create a new task worktree/window
   - resume an existing task window
   - request a task-local review/commit/merge check
   - mark a task window complete after merge-back
5. If a new task window is required:
   - use `references/worktree-bootstrap.md`
   - preserve the current `TMUX_ORCH_ROOT`
   - instruct the forked session to continue as `task-window-orchestrator-skill`
6. When a task window becomes the active focus, let
   `task-window-orchestrator-skill` own:
   - task-local phase
   - lane plan
   - review decision flow
   - commit-stage dispatch
   - merge-ready handoff
7. Maintain project/window coordination state:
   - project phase
   - task status
   - blockers
   - dependency edges
   - next active window
8. Report the active window map, blockers, merge-ready windows, and next
   handoff.

## References

- `references/worktree-bootstrap.md`
- `docs/tmux-orch-state-contract.md`

## Standard Manual Flow (Recommended)

```bash
session_name="$(tmux display-message -p '#S')"
session_slug="$(printf '%s' "$session_name" | tr '/: ' '___')"
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/${session_slug}}"
tmux/bin/orch init --root "$state_root"
tmux/bin/orch status --root "$state_root"
```

If a new task window is needed, follow
`references/worktree-bootstrap.md`. Once the target task window exists, enter
`task-window-orchestrator-skill` inside that window and let it own the task's
local lifecycle.

## Output Format

```text
## Project State
- project_context:
- project_phase:
- coordination_window:

## Task Windows
- active_windows:
- blocked_windows:
- review_ready_windows:
- merge_ready_windows:
- dependency_notes:

## Next Action
- action_type:
- target_window:
- bootstrap_needed:
- task_local_handoff_needed:

## Handoff
- next_skill:
- next_target:
- note:
```
