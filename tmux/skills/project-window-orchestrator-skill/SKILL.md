---
name: project-window-orchestrator-skill
description: v0.1.0 - Public project-level tmux orchestration entry that coordinates multiple worktrees and task windows, updates project/window state, and delegates pane realization without doing code work itself.
---

# Project Window Orchestrator Skill

## Trigger and Scope

Use this skill as the public orchestration entry for tracked tmux-based work
that may span multiple task windows or multiple worktrees.

This skill is project-scoped. It owns:

- deciding when a new task worktree/window is needed
- tracking active task windows for the project
- keeping project phase, task status, blockers, and dependencies visible
- deciding when a target task window needs pane or lane realization
- delegating pane creation and pane retirement to `task-pane-orchestrator-skill`

This skill does not perform code implementation itself.

In scope:

- manage multiple task windows as one tracked project surface
- call `task-worktree-bootstrap-skill` when a new worktree/window must be
  created
- register and refresh project/task-window state in `tmux-orch` when that
  layer exists
- choose which task window is active, blocked, review-ready, or complete
- decide when coder, issue-gate, or reviewer lanes are needed for a target
  task window
- coordinate sequencing across worktrees without drifting into code ownership

Out of scope:

- direct code implementation
- low-level `tmux split-window` mechanics
- reviewer/coder/issue-gate lane work itself
- replacing tmux runtime routing with JSON state

## Core Purpose

- Treat the project as the durable coordination unit.
- Keep one task per task window and one worktree per task window.
- Separate project/window coordination from pane realization.
- Keep pane lifecycle and lane startup subordinate to project-level policy.
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
- `bootstrap_policy=delegate-task-worktree-helper`
- `pane_policy=delegate-task-pane-orchestrator`
- `execution_mode=coordination-only`
- `writer_policy=lanes-only`

## Coordination Model

Project-scoped ownership:

- project objective
- project phase
- active task-window set
- window dependency and blocker interpretation
- which task window needs action next

Task-window realization delegated out:

- `task-worktree-bootstrap-skill` creates a new worktree and initial task
  window when needed
- `task-pane-orchestrator-skill` realizes pane layout and lane startup inside
  a specific task window

## External State Contract

When `tmux-orch` exists, this skill should:

- initialize or reuse the orchestration state root
- register and refresh task-window snapshots
- keep project/window status visible when a shared state root is available
- treat tmux runtime state as the live routing truth
- delegate pane registration to `task-pane-orchestrator-skill`

Reference:

- `docs/tmux-orch-state-contract.md`

## Guardrails

- Do not write production code from this skill.
- Do not split panes directly unless you are explicitly executing
  `task-pane-orchestrator-skill` within a target task window.
- Do not let bootstrap become the public entry; bootstrap is a helper.
- Do not let pane orchestration redefine project priorities or task sequencing.
- Do not claim project-wide shared durable state if the current `tmux-orch`
  deployment is still Phase A session-scoped only.

## Recommended Task Sequence

1. enter `project-window-orchestrator-skill`
2. inspect current project windows, blockers, and target tasks
3. if a new task window is needed, call `task-worktree-bootstrap-skill`
4. if a target task window needs lanes, enter `task-pane-orchestrator-skill`
5. keep coordinating handoffs and phase transitions across task windows

## Workflow

1. Confirm the current coordination context:
   - current repo root when relevant
   - current tmux session/window
   - existing tracked task windows
2. Inspect current project state:
   - active windows
   - blocked windows
   - review-ready windows
   - dependency constraints between windows
3. If `tmux-orch` exists, initialize or reuse the state root and refresh known
   window records.
4. Decide whether the next action is:
   - create a new task worktree/window
   - resume an existing task window
   - advance a task window's phase
   - request review in a task window
5. If a new task window is required, call `task-worktree-bootstrap-skill` and
   hand it:
   - `repo_root`
   - `task_kind`
   - `task_slug`
   - the expectation that the forked session returns to
     `project-window-orchestrator-skill`
6. When a target task window needs lane realization, delegate to
   `task-pane-orchestrator-skill` inside that task window.
7. Maintain project/window coordination state:
   - project phase
   - task status
   - blockers
   - dependency edges
   - next active window
8. Keep coder/reviewer/issue-gate work in lane panes rather than absorbing that
   work into the coordinator.
9. Report the active window map, dependencies, blockers, and next handoff.

## Standard Manual Flow (Recommended)

```bash
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch}"
tmux/bin/orch init --root "$state_root"
tmux/bin/orch status --root "$state_root"
```

If a new task window is needed, continue by invoking
`task-worktree-bootstrap-skill` with the chosen task kind and slug. Once the
target task window exists, register or refresh that task window and decide
whether it needs pane realization through `task-pane-orchestrator-skill`.

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
- dependency_notes:

## Next Action
- action_type:
- target_window:
- bootstrap_needed:
- pane_realization_needed:

## Handoff
- next_skill:
- next_target:
- note:
```
