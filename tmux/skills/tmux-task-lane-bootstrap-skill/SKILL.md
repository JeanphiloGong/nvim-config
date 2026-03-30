---
name: tmux-task-lane-bootstrap-skill
description: v0.1.3 - Internal helper that realizes lane layout, lane startup, pane_id registration, and phase-scoped lane retirement inside one task window after task-level orchestration has already chosen the next local action.
---

# Tmux Task Lane Bootstrap Skill

## Trigger and Scope

Use this skill only as an internal helper when either:

- `$tmux-task-orchestrator-skill` has already decided that the current task
  window needs lane realization, lane refresh, or phase-scoped pane retirement
- `$tmux-lane-dispatch-skill` has already decided that one lane should be
  started through the fast dispatch path

This skill is not a public role.

In scope:

- create or refresh task-local panes
- capture canonical `pane_id` values
- register panes and pane roles in `tmux-orch` when used
- fork child lanes from the current orchestrator session
- send role-first startup prompts
- retire or recreate phase-scoped panes when task-window policy has authorized it

Out of scope:

- deciding which task should run next
- deciding whether issue-gate/reviewer/commit is needed in the abstract
- commit-stage or merge-back decisions
- direct implementation
- public fast-path intent selection

## Required Inputs

- `task_context`
- `lane_plan`

## Optional Inputs

- `phase`
- `target_role`
- `worktree_path`

## Optional Environment Inputs

- `TMUX`
- `CODEX_SESSION_ID`
- `CODEX_THREAD_ID`
- `TMUX_ORCH_ROOT`
- `WORKTREE_ORCH_LAYOUT`
- `WORKTREE_ORCH_SECONDARY_ROLE`

## Fixed Defaults

- `routing_key=pane_id`
- `phase_scope=non-orchestrator-lanes`
- `message_mode=literal-enter`
- `execution_mode=lane-bootstrap-only`
- `coder/reviewer fork profile=gpt-5.4/xhigh`
- `issue-gate fork profile=gpt-5.4-mini/xhigh/fast`

## Guardrails

- Do not use this skill as the public task owner.
- Do not decide project or task policy here; realize the already chosen lane plan.
- In Codex TUI flows, do not add `--full-auto` to child `codex fork` commands.
- For coder and reviewer lanes, override the fork to `gpt-5.4` with
  `model_reasoning_effort=xhigh` so they do not inherit the lightweight
  orchestrator profile.
- For issue-gate lanes, explicitly use `gpt-5.4-mini` with
  `model_reasoning_effort=xhigh` and `service_tier=fast`.
- Do not embed the lane startup prompt directly in the `codex fork` command;
  send it only after fork readiness is confirmed.
- Use tmux `pane_id` as the only machine routing key.
- Use a dedicated reviewer pane for formal review.

## Workflow

1. Confirm the current task window and current orchestrator pane.
2. Read the lane plan already chosen by the caller.
3. Create, refresh, or retire panes as instructed by that plan.
4. Capture each pane's `pane_id` immediately.
5. Register panes and fork provenance in `tmux-orch` when used.
6. Fork child lanes from the current orchestrator session without embedding the
   startup prompt in the `codex fork` command.
7. Confirm the child pane has entered Codex.
8. Send role-first prompts that include:
   - current role and task context
   - `window_id`, current `pane_id`, `orchestrator_pane_id`, and `TMUX_ORCH_ROOT`
   - the required handoff message envelope
   - how the lane should refresh its own pane status and append a matching
     handoff in `tmux-orch` when available
   - how the lane should continue in tmux-only degraded mode when durable state
     registration is unavailable
9. Return the resolved pane map to the calling role.

## References

- `references/pane-lane-bootstrap.md`
- `../tmux-project-orchestrator-skill/docs/tmux-orch-state-contract.md`

## Output Format

```text
## Pane Plan
- layout:
- phase:
- target_roles:

## Pane Map
- orchestrator_pane:
- coder_pane:
- issue_gate_pane:
- reviewer_pane:

## Verification
- pane_ids_captured:
- tmux_orch_registered:
- fork_status:

## Handoff
- upstream_target:
- note:
```
