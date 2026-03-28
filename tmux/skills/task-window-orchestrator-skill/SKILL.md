---
name: task-window-orchestrator-skill
description: v0.1.0 - Manage one task window as the durable task unit, coordinating task status, phase changes, lane plans, and tmux-orch window state without owning pane split mechanics.
---

# Task Window Orchestrator Skill

## Trigger and Scope

Use this skill after `task-worktree-bootstrap-skill` has created the task
worktree, opened the initial tmux window, and forked the current session into
that window.

This skill is window-scoped. It owns one task window as one task unit and
decides:

- what the current task phase is
- whether issue, coding, review, or fix lanes are needed
- when pane layout should be created or changed
- when the current phase is complete enough to move forward

In scope:

- confirm task identity for one tmux window and one worktree
- register and refresh task-window state in `tmux-orch` when that layer exists
- choose a lane plan for the current phase
- call `task-pane-orchestrator-skill` when pane realization or pane retirement
  is needed
- decide when review should begin and require a fresh reviewer pane
- keep task-level handoffs, blockers, and current phase visible

Out of scope:

- creating the worktree itself
- opening the initial task window
- low-level `tmux split-window` mechanics
- direct code implementation
- project-wide scheduling across multiple task windows

## Core Purpose

- Treat one tmux window as one task boundary.
- Keep task status and task phase explicit instead of implicit in agent memory.
- Separate task-window policy from pane creation mechanics.
- Ensure pane orchestration is driven by current task state rather than ad hoc
  pane creation.
- Keep reviewer creation task-safe: review must request a fresh reviewer pane
  instead of reusing issue-gate state.

## Required Inputs

- `task_summary`: concise task statement for this window

## Optional Inputs

- `phase`: default infer from current state; otherwise start with `phase1`
- `window_id`: current tmux `window_id`
- `window_name`: current tmux window name
- `worktree_path`: current working directory
- `branch`: current git branch

## Optional Environment Inputs

- `TMUX`
- `CODEX_SESSION_ID`
- `CODEX_THREAD_ID`
- `TMUX_ORCH_ROOT`

## Fixed Defaults

- one task window maps to one task and one worktree
- one active phase at a time
- reviewer startup requires a fresh reviewer pane
- task-window state is durable when `tmux-orch` exists, but live routing still
  stays in tmux
- pane realization is delegated to `task-pane-orchestrator-skill`

## Window Model

Window-scoped ownership:

- task summary
- worktree path
- branch
- current phase
- task status
- lane plan

Pane-scoped ownership belongs to `task-pane-orchestrator-skill`:

- pane creation and split direction
- `pane_id` capture
- pane titles
- fork startup commands
- pane-to-pane routing

## External State Contract

When `tmux-orch` exists, this skill should:

- register the task window after confirming task context
- keep window-level task fields current
- decide when pane registration or pane retirement must happen
- use pane ids for durable handoff references, not pane titles
- treat tmux runtime options as the live pane map, not the JSON files

Reference:

- `../task-pane-orchestrator-skill/docs/tmux-orch-state-contract.md`

## Guardrails

- Do not create new task windows. That belongs to
  `task-worktree-bootstrap-skill`.
- Do not manage multiple task windows. That belongs to a future
  `project-window-orchestrator-skill`.
- Do not call a reviewer lane valid unless it came from a fresh pane in the
  current review phase.
- Do not let the pane layer redefine task scope or task status on its own.

## Recommended Task Sequence

1. `task-worktree-bootstrap-skill`
2. `task-window-orchestrator-skill`
3. `task-pane-orchestrator-skill` when lane realization is needed
4. downstream lane work (`issue-gate`, `coder`, `reviewer`)

## Workflow

1. Confirm the current session is already inside the intended task worktree and
   task window.
2. Inspect repo state, branch, task context, and any prior task-window state.
3. Resolve current task phase and task status.
4. If `tmux-orch` exists, register or refresh the task window record.
5. Decide the lane plan for the current phase:
   - no secondary lanes yet
   - coder only
   - coder + issue-gate
   - coder + reviewer
6. If pane realization is needed, hand off to `task-pane-orchestrator-skill`.
7. Track phase status at the window level:
   - issue unresolved
   - coding active
   - review requested
   - fix-now
   - phase complete
8. If formal review begins, require a fresh reviewer pane rather than reusing
   issue-gate state.
9. On phase transition, authorize pane retirement and pane recreation through
   the pane layer.
10. Report the active phase, lane plan, blockers, and next handoff target.

## Standard Manual Flow (Recommended)

```bash
window_id="$(tmux display-message -p '#{window_id}')"
window_name="$(tmux display-message -p '#W')"
worktree_path="$(pwd)"
branch="$(git symbolic-ref --quiet --short HEAD)"
phase="${TASK_PHASE:-phase1}"
task_summary="${TASK_SUMMARY:-define me}"

tmux/bin/orch register-window \
  --window-id "$window_id" \
  --window-name "$window_name" \
  --worktree-path "$worktree_path" \
  --branch "$branch" \
  --task "$task_summary" \
  --phase "$phase"
```

If the current phase needs lane realization, continue by invoking
`task-pane-orchestrator-skill` for the chosen lane plan rather than creating
panes ad hoc.

## Output Format

```text
## Task Window
- window_id:
- window_name:
- worktree_path:
- branch:

## Task State
- task_summary:
- phase:
- status:
- blockers:

## Lane Plan
- current_plan:
- pane_changes_needed:
- reviewer_required:

## Handoff
- next_skill:
- next_target:
- note:
```
