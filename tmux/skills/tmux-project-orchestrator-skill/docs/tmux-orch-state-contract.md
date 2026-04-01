# tmux-orch State Contract

This document defines the minimal contract between tracked tmux orchestration
skills and an optional external `tmux-orch` state layer.

Purpose:

- keep machine routing stable across panes and phase transitions
- make pane, window, and handoff state durable enough for audit and recovery
- keep state ownership explicit so the plugin does not replace skill policy

This is a contract document, not an implementation guide for shell tooling.

## Responsibilities

Skills own policy:

- deciding task scope, phase order, and lane startup
- deciding whether `issue-gate` or `reviewer` is needed
- deciding whether disjoint parallel coder lanes are explicitly approved

`tmux-orch` owns state:

- recording project, window, pane, handoff, and phase state
- resolving machine routing targets from canonical pane identities
- validating invariants cheaply and repeatedly

Bootstrap owns boundary creation only:

- create the worktree
- create or verify the tmux task window
- fork the current session into that window
- hand off the context needed for downstream state registration

## Source of Truth Rules

There must be one routing truth and one durable audit trail.

Live routing truth:

- tmux `pane_id`
- session tmux option `@project_orchestrator_pane` for upward task-to-project
  routing
- window-scoped tmux options such as `@pane_orchestrator`, `@pane_coder`, and
  related role mappings

Durable audit and recovery state:

- append-only event logs such as handoffs and phase transitions
- current snapshots for project, window, and pane registration

Rules:

1. When live tmux state is available, it wins for message routing.
2. Durable state must never override a live `pane_id` lookup.
3. Pane titles are display only and must never become the sole routing key.
4. Pane indexes are unstable and must never be treated as canonical machine
   identity.
5. When durable state conflicts with live tmux state, reconcile durable state to
   the live pane map before sending more machine-targeted messages.

## State Root Rule

Phase A may still use a session-scoped state root for single task-window flows.

When project-level multi-window coordination becomes active, prefer a shared
state root across the tracked project.

Implications:

- Phase A session-scoped roots are acceptable when one tmux session is the
  practical orchestration boundary
- do not fragment project-level state by storing one isolated state root inside
  each task worktree once cross-window coordination is expected
- prefer an explicit external state root or another shared location that stays
  stable across sibling worktrees
- treat the state root as operational data, not as committed project source

## State Layers

### Project Layer

Use this layer to record project-wide coordination state when
`$tmux-project-orchestrator-skill` is active. Phase A `tmux-orch` may not
persist this layer by default yet, but the contract reserves it for that
coordinator.

Minimum fields:

```json
{
  "project": "agents-spec",
  "session_name": "main",
  "project_orchestrator_window": "@0",
  "project_orchestrator_pane_id": "%71",
  "current_phase": "phase1",
  "updated_at": "2026-03-27T12:00:00Z"
}
```

### Task Window Layer

One task window should still represent one task and one worktree.

Minimum fields:

```json
{
  "window_id": "@3",
  "window_name": "wt-tmux-orch-contract",
  "repo_root": "/repo",
  "worktree_path": "/repo/../_worktrees/refactor-tmux-orch-contract",
  "branch": "task/refactor/20260327-tmux-orch-contract",
  "task": "define tmux-orch state contract",
  "status": "in_progress",
  "phase": "phase1",
  "next_action": "dispatch-coder",
  "review_status": "pending",
  "commit_status": "pending",
  "merge_status": "not_ready",
  "owner_orchestrator_pane_id": "%107",
  "depends_on": [],
  "updated_at": "2026-03-27T12:00:00Z"
}
```

### Task To Project Handoffs

Upward handoff is always owned by `$tmux-task-orchestrator-skill`, never by an
individual coder/reviewer/issue-gate lane and never directly by
`$git-commit-skill`.

Minimum fields:

```json
{
  "ts": "2026-03-27T12:30:00Z",
  "window_id": "@3",
  "from_pane_id": "%107",
  "to_pane_id": "%71",
  "from_role": "orchestrator",
  "to_role": "project-orchestrator",
  "type": "merge-ready",
  "payload": {
    "task_branch": "task/refactor/20260327-tmux-orch-contract",
    "commit": "abc1234",
    "refs_line": "ISSUE: #41",
    "next_request": "schedule-merge",
    "note": "local commit is ready for project-level integration"
  }
}
```

Allowed upward handoff `type` values:

- `merge-ready`
- `merge-complete`
- `blocked`
- `needs-policy`

### Pane Layer

Minimum fields:

```json
{
  "window_id": "@3",
  "pane_id": "%114",
  "role": "coder",
  "scope": "phase",
  "phase": "phase1",
  "status": "active",
  "forked_from_session_id": "019d...",
  "forked_from_pane_id": "%107",
  "registered_at": "2026-03-27T12:01:00Z",
  "retired_at": null
}
```

Rules:

- `forked_from_session_id` is required for every non-orchestrator pane
- `forked_from_pane_id` is strongly recommended when the orchestrator pane is
  known at registration time
- `phase` may be omitted only for window-scoped panes such as `orchestrator`

## Event Schemas

### Handoffs

Handoffs must be append-only and must include pane identity, not only roles.

Minimum fields:

```json
{
  "ts": "2026-03-27T12:05:00Z",
  "window_id": "@3",
  "from_pane_id": "%114",
  "to_pane_id": "%107",
  "from_role": "coder",
  "to_role": "orchestrator",
  "type": "review-ready",
  "payload": {
    "changed_files": ["agent-specs/.../SKILL.md"],
    "checks_run": ["rg -n tmux-orch agent-specs/..."],
    "risks": ["project-layer contract not implemented yet"]
  }
}
```

### Phases

Phase events must also be append-only.

Minimum fields:

```json
{
  "ts": "2026-03-27T12:10:00Z",
  "window_id": "@3",
  "event": "phase-close",
  "phase": "phase1",
  "retired_panes": ["%114", "%118"]
}
```

### Decisions

Decision logs are optional for v1, but when present they should stay append-only
and record why a sequencing or routing decision was made.

## Command Semantics

An implementation may choose different command names, but the following
behaviors are the minimal contract:

- `register-window`
  - records the task window snapshot
  - must capture `window_id`, `worktree_path`, branch, task, and active phase
  - should capture `next_action`, task-local review/commit/merge state, and
    `owner_orchestrator_pane_id` when that information is known
- `register-project`
  - records project-level state for the current tmux session
  - should capture `project_orchestrator_window` and
    `project_orchestrator_pane_id`
  - should align with the live tmux session option
    `@project_orchestrator_pane`
- `register-pane`
  - records pane identity, role, scope, status, and fork provenance
- `handoff`
  - appends a structured record with sender and recipient `pane_id`
- `phase-start`
  - records a new phase as active for the window
- `phase-close`
  - records phase closure and retires phase-scoped panes from the active map
- `validate`
  - checks invariants and returns non-zero on failure

## Required Invariants

At minimum, validation must fail when any of the following is violated:

1. a task window does not have exactly one active orchestrator
2. more than one active coder exists for the same phase without explicit
   disjoint-write approval
3. formal review is requested without an active reviewer pane
4. a reviewer pane reuses the identity of the current or most recent
   `issue-gate` pane
5. a non-orchestrator pane is active without recorded `forked_from_session_id`
6. a phase closes while previous phase-scoped panes remain active in the
   canonical pane map
7. a handoff references sender or recipient `pane_id` values that do not exist
   in the current or recorded pane map
8. machine routing attempts to resolve by pane title or pane index instead of
   `pane_id`
9. a registered project orchestrator pane is stale or task-to-project handoffs
   target a different pane id

Recommended machine-readable failure ids:

- `missing-orchestrator`
- `duplicate-coder-phase`
- `missing-reviewer`
- `reviewer-reused-issue-pane`
- `missing-fork-provenance`
- `stale-phase-pane-map`
- `unknown-handoff-pane`
- `invalid-routing-key`
- `stale-project-orchestrator-target`

## Skill Integration Rules

### $tmux-task-window-bootstrap-skill

This internal helper should not become the durable state owner for downstream
orchestration.

Bootstrap handoff should provide enough context for downstream registration:

- `repo_root`
- `worktree_path`
- `session_name`
- `window_name`
- current `window_id` when available
- current orchestrator session id

### $tmux-project-orchestrator-skill

When `tmux-orch` exists, `$tmux-project-orchestrator-skill` should:

- own project-wide coordination across task windows and worktrees
- register the canonical project orchestrator pane in both tmux session state
  and `project-state.json`
- register or refresh task windows after confirming task context
- keep project phase, window status, dependencies, and blockers visible when a
  shared state root exists
- decide when a target task window needs to be created, resumed, paused, or
  closed
- use `$tmux-task-window-bootstrap-skill` when a new task window must be created
- hand task-local lifecycle ownership to `$tmux-task-orchestrator-skill`
- emit phase events when lifecycle support exists

### $tmux-task-orchestrator-skill

When `tmux-orch` exists, `$tmux-task-orchestrator-skill` should:

- keep task-window `status`, `phase`, and `next_action` visible
- keep review/commit/merge state visible when that information is known
- decide when pane/lane realization is required
- decide whether issue-gate, reviewer, commit-stage, or merge-back should run
- turn each handoff into an explicit local `next_action`
- treat `$git-commit-skill` as a local capability only
- use a deterministic task-to-project handoff after commit or after confirmed
  manual cherry-pick / merge completion

### $tmux-task-lane-bootstrap-skill

When `tmux-orch` exists, `$tmux-task-lane-bootstrap-skill` should:

- register each newly created pane immediately after capture of its `pane_id`
- keep window-scoped tmux options aligned with the active pane map
- emit structured handoffs with sender and recipient `pane_id`
- retire phase-scoped panes only when the window-level phase transition
  authorizes that change

### Lane Prompt Contract

When a lane pane is created, the startup prompt should give the lane enough
context to report back without guessing. The prompt is sent explicitly by the
caller with raw `tmux send-keys`; it is not part of lane bootstrap itself.

Minimum prompt fields:

- role name
- `window_id`
- current `pane_id`
- `orchestrator_pane_id`
- current phase
- task context
- `TMUX_ORCH_ROOT` when `tmux-orch` is in use

Minimum completion behavior:

- send a structured handoff back to the orchestrator pane
- append the same handoff to `tmux-orch`
- refresh the lane's own pane record if its status changed

## Non-Goals

This contract does not authorize the plugin to:

- plan the project or task
- decide review outcomes
- choose architecture
- replace skill prompts with hidden policy
- become an always-on daemon by default
