---
name: task-window-orchestrator-skill
description: v0.1.0 - Public task-local tmux orchestration role that owns one task window from local plan confirmation through lane dispatch, review, commit, merge-back handoff, and closure.
---

# Task Window Orchestrator Skill

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
