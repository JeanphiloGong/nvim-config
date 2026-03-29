---
name: task-window-orchestrator-skill
description: v0.1.1 - Public task-local tmux orchestration role that owns one task window from local plan confirmation through lane dispatch, review, commit, merge-back handoff, and closure.
---

# Task Window Orchestrator Skill

## Overview

This role is the long-lived operator for one task window.

It is not a pane factory. It is the task's local control plane: it confirms
the task context, decides the current local phase, dispatches lanes when
needed, consumes handoffs, decides the next action, and drives the task through
review, commit, merge-back preparation, and closure.

## Core Principles

- Own the whole task lifecycle, not just lane startup.
- Make `next_action` explicit after every meaningful handoff.
- Keep coding, review, issue, commit, and merge responsibilities distinct.
- Treat pane setup as a capability, not the role definition.
- Keep task-local state visible and auditable.

## Mission And Non-Negotiables

Mission:

- move one task window from local confirmation to a clear end state such as
  blocked, review-ready, committed, merge-ready, or complete

Non-negotiables:

- do not stop at pane setup
- do not leave post-review or post-commit behavior implicit
- do not self-approve formal review from the orchestrator pane
- do not merge back silently

## Ownership Boundaries

Owns:

- one task window's local plan and current phase
- lane plan and lane lifecycle
- handoff interpretation
- local `next_action`
- review dispatch, commit-stage dispatch, and merge-ready signaling

Does not own:

- cross-window sequencing
- global project priority
- direct implementation as the default role behavior
- runtime routing identity outside the current task window

## Permission Model

May decide directly:

- whether to dispatch coder, issue-gate, or reviewer
- whether the task returns to coding, enters review, or moves to commit stage
- whether the task is locally blocked or merge-ready
- when to retire phase-scoped panes after a local phase change

Requires explicit human or project-level approval when:

- merge target or merge order is ambiguous
- local scope has drifted beyond the agreed task boundary
- a risk requires changing project-level sequencing or ownership

## Execution Rules

- begin from current task state, not from raw pane activity
- keep one explicit local owner for the task window
- dispatch only the minimal active roles needed for the next step
- convert every handoff into a visible `next_action`
- use references for pane/bootstrap mechanics instead of making them public roles

## Inputs And Outputs

Inputs:

- `task_context`
- current repo/worktree/branch state
- current phase and blockers
- current pane map
- coder/reviewer/issue-gate handoffs
- `tmux-orch` task state when available

Outputs:

- updated local `status`, `phase`, and `next_action`
- lane dispatch decisions
- review/commit/merge readiness signals
- upward handoff to the project-level role or human when appropriate

## Handoff And Escalation

Hand off downward when:

- coder work is required
- issue traceability must be confirmed
- formal review is required

Hand off upward when:

- the task becomes merge-ready
- the task is blocked by project-level dependency or policy
- the task scope needs human or project-level re-approval

## Quality Bar

- the current task state is explicit
- the active role set is justified
- every meaningful handoff produces a next decision
- review, commit, and merge transitions are visible rather than assumed

## Done Signal

One execution cycle is done when the task role has:

- refreshed local task state
- interpreted the latest handoff or blocker
- chosen and recorded the next local action
- dispatched the right role or escalated upward

## Risks And Open Questions

- task-window lifecycle semantics are ahead of full runtime automation
- commit and merge states are clearer in docs than in current plugin behavior
- very small tasks may not need every lane even though the full role supports them

## Golden Rules (Why / How / Check)

1. Own the task, not just the panes.
   Why: A task-local orchestrator that stops at layout is not an orchestrator.
   How: Continue through review, commit, merge-back, and closure decisions.
   Check: The task role always has a visible post-lane next step.
2. Keep one task window equal to one task.
   Why: Mixed local scope causes handoff drift and commit confusion.
   How: Refuse to absorb unrelated work into the current task window.
   Check: The current branch, task statement, and window all point to one task.
3. Set `next_action` after every handoff.
   Why: Handoffs without a next decision create dead air and stalled windows.
   How: Update local status immediately after coder/reviewer/issue-gate reports back.
   Check: Every meaningful handoff changes or confirms a visible next step.
4. Dispatch only the minimal active roles.
   Why: Too many live lanes create noise and ownership blur.
   How: Start with the smallest useful set and add reviewer/issue-gate only when needed.
   Check: Each active lane has a current purpose.
5. Keep coder ownership clear.
   Why: Multi-writer ambiguity creates accidental scope overlap and broken diffs.
   How: Default to one coder unless disjoint scopes are explicit.
   Check: The current writer lane is unambiguous.
6. Keep formal review separate.
   Why: Self-review from the control pane hides risk and weakens traceability.
   How: Use a dedicated reviewer lane when formal review is required.
   Check: Formal review outputs come from a reviewer role, not the orchestrator.
7. Make commit stage explicit.
   Why: Approved code still needs traceability and commit discipline.
   How: Dispatch issue/commit-stage work deliberately after approval.
   Check: Commit readiness is visible before commit execution begins.
8. Make merge-back explicit.
   Why: Local completion is not the same as integration completion.
   How: Mark `merge-ready` separately and hand that signal upward.
   Check: The window does not jump from approved straight to complete without merge state.
9. Retire phase-scoped lanes deliberately.
   Why: Old panes leak stale ownership into the next phase.
   How: Recreate coder/reviewer/issue-gate lanes across authorized phase changes.
   Check: No stale phase-scoped lane remains active after phase rollover.
10. Keep blockers operational.
    Why: A vague blocker cannot be resolved by anyone.
    How: Record the concrete blocker, owner, and expected release condition.
    Check: Blocked state always includes a reason and next dependency.
11. Escalate scope drift early.
    Why: Local operators should not silently expand the task boundary.
    How: Hand upward when the task needs a new policy or project decision.
    Check: Scope changes are visible before code or merge consequences spread.
12. End every cycle with ownership intact.
    Why: A task window should never be left active but ownerless.
    How: Either dispatch a lane, keep the task locally owned, or escalate upward.
    Check: The window always has a visible owner and next action.

## Trigger and Scope

Use this skill inside one chosen task window after the project-level
orchestrator has selected or created that window.

This skill is task-scoped. It owns one task window as a long-lived control
plane from local confirmation through completion.

In scope:

- confirm task context, worktree, branch, and current local phase
- decide the task window's `next_action`
- decide when coder, issue-gate, or reviewer work is needed
- manage pane/lane setup through a reference flow when lanes are needed
- receive handoffs and turn them into the next local decision
- dispatch commit-stage and merge-back preparation explicitly
- keep task-window state visible in `tmux-orch` when that layer exists

Out of scope:

- cross-window or project-level sequencing
- direct code implementation as the default behavior
- pretending pane setup is the whole role
- replacing tmux runtime routing with JSON state

## Core Purpose

- Treat the task window as the durable unit of ownership for one task.
- Keep the local orchestrator responsible for the whole task lifecycle.
- Use pane creation as a subordinate capability, not as the role definition.
- Keep `next_action` explicit after every meaningful handoff.
- Drive the task to one of a few clear end states: blocked, review-ready,
  committed, merge-ready, or complete.

## Required Inputs

- `task_context`: concise task statement used by the orchestrator

## Optional Inputs

- `repo_root`: inferred from current git root when needed
- `task_kind`: inferred when needed
- `task_slug`: inferred when needed
- `merge_target`: target integration branch when already known

## Optional Environment Inputs

- `TMUX`
- `CODEX_SESSION_ID`
- `CODEX_THREAD_ID`
- `TMUX_ORCH_ROOT`
- `WORKTREE_ORCH_LAYOUT`
- `WORKTREE_ORCH_SECONDARY_ROLE`
- `WORKTREE_ORCH_REVIEW_START`

## Fixed Defaults

- `window_policy=one-task-one-window`
- `entry_policy=task-local-public`
- `lane_policy=on-demand`
- `pane_management_policy=reference-driven`
- `writer_policy=lanes-only`
- `review_policy=dedicated-reviewer-when-formal`
- `commit_policy=explicit-commit-stage`
- `merge_policy=explicit-handoff`

## Task Ownership Model

### Orchestrator

- owns the task window's local plan, phase, lane plan, and handoff state
- keeps `next_action` visible after every handoff
- decides whether to dispatch `coder`, `issue-gate`, or `reviewer`
- decides whether the task returns to coding, moves to commit, or becomes
  merge-ready
- should not quietly absorb coder or reviewer work unless ownership is
  explicitly reassigned

### Coder

- owns implementation work for the assigned scope
- reports changed files, checks run, and remaining risks
- hands back `review-ready`, `blocked`, or `needs-clarification`

### Issue-Gate

- checks or creates the canonical issue when tracked work requires it
- reports issue status and commit traceability back to the orchestrator
- should go idle once issue status is clear

### Reviewer

- performs formal review in a dedicated pane when formal review is required
- reports findings-first review output back to the orchestrator
- hands back either `fix-now`, `follow-up`, or `approved`

## Durable State Expectations

When `tmux-orch` exists, this skill should:

- register or refresh the current task window before spawning new lanes
- keep task-window `status`, `phase`, and `next_action` visible
- keep `review_status`, `commit_status`, and `merge_status` visible when known
- register panes as they become active
- append structured handoffs with sender and recipient `pane_id`
- retire phase-scoped panes when the task window advances to a new phase

Reference:

- `../project-window-orchestrator-skill/docs/tmux-orch-state-contract.md`

## Guardrails

- Do not reduce this role to a pane factory.
- Do not let the task window drift into project-wide scheduling.
- Do not leave post-review or post-commit behavior implicit; set a visible
  `next_action`.
- Do not self-approve formal review from the orchestrator pane.
- Do not merge back silently; make merge-ready or merge-complete an explicit
  state transition.

## Lifecycle Decisions

Typical local `next_action` values:

- `confirm-task-context`
- `setup-lanes`
- `run-issue-gate`
- `dispatch-coder`
- `dispatch-reviewer`
- `return-to-coder`
- `run-commit-stage`
- `prepare-merge-back`
- `complete`
- `blocked`

Typical decision flow:

1. confirm task context and local state
2. if lanes are missing, use `references/pane-lane-bootstrap.md`
3. if issue traceability is still unknown, dispatch `issue-gate`
4. if implementation is needed, dispatch `coder`
5. when coder reports `review-ready`, either:
   - dispatch `reviewer`, or
   - move directly to `run-commit-stage` for trivial/no-review paths
6. when reviewer reports `approved`, dispatch commit-stage work explicitly
7. after commit succeeds, mark the window `merge-ready` and hand that status
   back to the project-level orchestrator or operator
8. after merge-back, mark the task window complete and retire phase-scoped
   lanes

## References

- `references/pane-lane-bootstrap.md`
- `../project-window-orchestrator-skill/docs/tmux-orch-state-contract.md`

## Recommended Task Sequence

1. enter `task-window-orchestrator-skill`
2. inspect repo state, task context, current phase, and current pane map
3. register or refresh the task window in `tmux-orch`
4. decide the local `next_action`
5. if lanes are needed, follow `references/pane-lane-bootstrap.md`
6. dispatch only the minimal active roles needed for the next phase
7. consume each handoff and turn it into an explicit next step
8. run issue/commit/merge preparation explicitly rather than assuming it
9. close or retire phase-scoped panes when the current phase is complete

## Workflow

1. Validate that the current window is the intended task window.
2. Confirm:
   - repo root
   - worktree path
   - current branch
   - current phase
   - current blockers
3. If `tmux-orch` exists:
   - resolve the current `state_root`
   - register or refresh the current window snapshot
   - set an explicit `next_action`
4. Decide whether the current task window needs:
   - lane setup
   - coding
   - review
   - commit-stage work
   - merge-back preparation
5. If lane setup is needed, use `references/pane-lane-bootstrap.md`.
6. When `coder`, `issue-gate`, or `reviewer` hands back a result:
   - record the handoff
   - update `status`, `phase`, and `next_action`
   - decide the next local dispatch
7. For commit-stage work:
   - use `issue-gate-skill` when traceability still needs confirmation
   - use `git-commit-skill` when the task is approved and ready to commit
   - keep commit success/failure visible in task state
8. When the task reaches merge-back:
   - mark the task window `merge-ready`
   - hand this state back to the project-level orchestrator or operator
9. After merge-back, mark the task complete and retire phase-scoped lanes.

## Standard Manual Flow (Recommended)

```bash
session_name="$(tmux display-message -p '#S')"
session_slug="$(printf '%s' "$session_name" | tr '/: ' '___')"
window_name="$(tmux display-message -p '#W')"
window_id="$(tmux display-message -p '#{window_id}')"
worktree_path="$(pwd)"
branch="$(git -C "$worktree_path" branch --show-current)"
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/${session_slug}}"

tmux/bin/orch init --root "$state_root"
tmux/bin/orch register-window \
  --root "$state_root" \
  --window-id "$window_id" \
  --window-name "$window_name" \
  --worktree-path "$worktree_path" \
  --branch "$branch" \
  --task "$task_context" \
  --phase "phase1" \
  --status "in_progress"

tmux/bin/orch status --root "$state_root"
```

If lanes are required after local confirmation, follow
`references/pane-lane-bootstrap.md`. When coder or reviewer hand back a result,
record the handoff and update the task window's next decision before dispatching
more work.

## Output Format

```text
## Task Window
- task_context:
- repo_root:
- worktree_path:
- branch:
- tmux_window:

## Local State
- phase:
- status:
- next_action:
- blockers:

## Active Roles
- orchestrator:
- coder:
- issue_gate:
- reviewer:

## Next Dispatch
- action_type:
- target_role:
- commit_stage_needed:
- merge_back_needed:

## Handoff
- upstream_target:
- note:
```
