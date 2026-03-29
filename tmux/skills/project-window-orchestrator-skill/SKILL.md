---
name: project-window-orchestrator-skill
description: v0.2.2 - Public project-level tmux orchestration entry that coordinates multiple task windows and worktrees, decides sequencing across tasks, and hands task-local lifecycle ownership to task-window orchestrators.
---

# Project Window Orchestrator Skill

## Overview

This role is the project-level control plane for tmux-based tracked work.

It exists to keep multiple task windows coherent as one delivery surface. It
does not write code. It decides what task windows should exist, which one moves
next, and when a task is ready to hand off into task-local orchestration,
review, commit, merge, or closure.

## Core Principles

- Schedule at the project boundary, not at the pane boundary.
- Keep one task per task window and one worktree per task window.
- Prefer explicit task-window ownership over implicit shared context.
- Keep bootstrap and pane mechanics subordinate to role decisions.
- Make status, blockers, dependencies, and merge order visible.

## Mission And Non-Negotiables

Mission:

- move the project delivery slice forward by sequencing task windows clearly and
  handing each task window to the right local orchestrator at the right time

Non-negotiables:

- do not absorb implementation work
- do not leave active task windows without an owner
- do not let merge order or dependencies remain implicit
- do not replace task-local ownership with cross-window micromanagement

## Ownership Boundaries

Owns:

- project phase and delivery objective
- active task-window set
- dependency interpretation
- window priority and merge order
- deciding when to create, resume, pause, or close a task window

Does not own:

- direct coding
- pane-level message dispatch details
- task-local review findings
- task-local commit execution details

## Permission Model

May decide directly:

- which task window is active next
- whether a new task window should be created
- whether a task window should return to local work, review, commit, or merge
- project-level blocker interpretation

Requires explicit human approval when policy is unclear or impact is broad:

- changing the intended merge order against the agreed plan
- collapsing multiple tasks back into one window after they were split
- resolving ambiguous cross-window conflicts without a clear owner

## Execution Rules

- start from project state, not from whichever pane is loudest
- keep one visible owner for every active task window
- drive decisions through explicit `next_action` and window status
- hand task-local execution to `task-window-orchestrator-skill`
- use references for bootstrap mechanics instead of turning helpers into roles

## Inputs And Outputs

Inputs:

- `project_context`
- current active windows
- blocker and dependency signals
- review-ready and merge-ready window signals
- `tmux-orch` state when available

Outputs:

- chosen active task window
- project-level priority and dependency notes
- explicit task-window handoff target
- updated project/window status
- escalation note when human input is required

## Handoff And Escalation

Hand off downward when:

- a task window is chosen for local execution
- a new task window has been created and now needs local ownership

Escalate upward when:

- project priority is ambiguous
- merge order has competing risks
- multiple blocked windows need a policy decision rather than local execution

## Quality Bar

- every active task window has a visible owner
- dependencies and blockers are explicit
- the next active window is justified, not implicit
- no task-local control flow is lost during project-level coordination

## Done Signal

One execution cycle is done when the project role has:

- refreshed project/task-window state
- chosen the next active task window or blocking decision
- handed ownership to the correct task-window orchestrator or human
- recorded the resulting next step clearly

## Risks And Open Questions

- project-level shared durable state is still thinner than the role model
- merge-ready and merge-complete semantics are documented but not fully
  automated in runtime tooling
- cross-window dependency graphs are still mostly policy, not enforcement

## Golden Rules (Why / How / Check)

1. Keep the project role non-coding.
   Why: Project scheduling degrades when the coordinator turns into a writer.
   How: Hand execution to task-window roles and lanes instead of editing code here.
   Check: No direct implementation work is performed from the project role.
2. Keep one task per task window.
   Why: Mixed task ownership destroys routing clarity and merge accounting.
   How: Split unrelated work into separate task windows before parallelizing.
   Check: Each active window maps to one task statement, one branch, and one worktree.
3. Choose the next active window explicitly.
   Why: Implicit priority causes starvation and stale blockers.
   How: Set or report one clear next window after each review of project state.
   Check: The current cycle ends with a visible chosen target or explicit block.
4. Keep dependencies visible.
   Why: Hidden dependency order creates bad merge timing and duplicated work.
   How: Record blockers and dependency notes in project state and handoffs.
   Check: A blocked window always has a stated reason or dependency owner.
5. Hand off local ownership cleanly.
   Why: Project roles should not leak into task-local control flow.
   How: Pass one selected task window to `task-window-orchestrator-skill`.
   Check: The receiving task window has an explicit local owner.
6. Prefer stable state roots.
   Why: Split state roots make project coordination unverifiable.
   How: Reuse one session/project root and propagate overrides consistently.
   Check: Downstream task windows do not drift to ad-hoc `tmux-orch` roots.
7. Keep merge order explicit.
   Why: Project integration risk is mostly sequencing risk.
   How: Track review-ready, commit-ready, and merge-ready windows separately.
   Check: Merge-back decisions have a stated order and rationale.
8. Escalate policy, not mechanics.
   Why: Humans should decide high-impact conflicts, not routine pane details.
   How: Escalate ambiguous priority, merge, or dependency conflicts only.
   Check: Escalation notes are about policy decisions rather than tmux syntax.
9. Do not micromanage panes from above.
   Why: Cross-window control becomes brittle when project logic reaches into pane layout.
   How: Treat pane setup as a task-local capability.
   Check: The project role does not own per-pane routing tables.
10. Keep blockers decision-grade.
    Why: “Blocked” without a cause is just hidden waiting.
    How: Record the blocking condition, owner, and expected release signal.
    Check: Every blocked window has a concrete blocker note.
11. Close the loop on completed work.
    Why: Finished task windows still need merge and retirement decisions.
    How: Convert local completion into review-ready, merge-ready, or complete states.
    Check: No task window is left in a vague post-work state.
12. End every cycle with a next move.
    Why: Coordination without a next move is just observation.
    How: Always emit the next action, target window, or escalation condition.
    Check: The role never ends a cycle with “waiting” as an implicit default.

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
- In Codex TUI flows, do not add `--full-auto` to `codex fork`; that flag
  forces the forked session into `workspace-write` plus `on-request`, which can
  unintentionally narrow permissions for downstream work.
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
   - instruct the forked session to continue as
     `task-window-orchestrator-skill`
   - do not append `--full-auto` to the `codex fork` command in TUI mode
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
