---
name: tmux-task-window-bootstrap-skill
description: v0.1.2 - Internal helper that creates a dedicated task worktree and tmux task window, forks the current session into it, and stops only after task-level ownership is ready.
---

# Tmux Task Window Bootstrap Skill

## Trigger and Scope

Use this skill only as an internal helper when
`$tmux-project-orchestrator-skill` has already decided that a new task needs
its own worktree and tmux window.

This skill is not a public role.

In scope:

- create a dedicated git worktree for one task
- create or verify the first tmux task window for that worktree
- fork the current Codex session into that window
- verify that task-local handoff is actually ready before stopping

Out of scope:

- project-level sequencing
- task-local lane planning
- direct implementation
- claiming handoff complete before the tmux window is live

## Required Inputs

- `repo_root`
- `task_kind`
- `task_slug`

## Optional Inputs

- `base_branch`
- `worktree_root`
- `window_name`

## Optional Environment Inputs

- `TMUX`
- `CODEX_SESSION_ID`
- `CODEX_THREAD_ID`
- `TMUX_ORCH_ROOT`

## Fixed Defaults

- `window_policy=one-task-one-window`
- `fork_policy=dispatch-tmux-task-orchestrator`
- `execution_mode=bootstrap-only`

## Guardrails

- Do not use this skill as the main public entry.
- Do not start implementation before the handoff prompt is processed.
- Do not report success until the tmux task window exists and fork dispatch has
  happened.
- In Codex TUI flows, do not add `--full-auto` to `codex fork`.
- Stop the parent agent after the fork succeeds.

## Workflow

1. Validate `repo_root`, `task_kind`, and `task_slug`.
2. Resolve `base_branch`, `branch`, `worktree_root`, and `worktree_path`.
3. Create the worktree if it does not already exist.
4. Create or verify the tmux task window for that worktree.
5. Fork the current Codex session into that tmux window.
   The injected child prompt must explicitly tell the new window to continue as
   `$tmux-task-orchestrator-skill`.
6. Verify:
   - `window_exists=yes`
   - `window_name` is known
   - `window_id` is known or resolvable
   - `fork_status=dispatched`
   - `handoff_ready=yes`
7. Stop after task-local ownership is ready.

## References

- `references/worktree-bootstrap.md`
- `../tmux-project-orchestrator-skill/docs/tmux-orch-state-contract.md`

## Output Format

```text
## Bootstrap State
- repo_root:
- branch:
- worktree_path:
- window_name:
- window_id:

## Verification
- window_exists:
- fork_status:
- handoff_ready:

## Next Handoff
- next_skill:
- next_target:
- note:
```
