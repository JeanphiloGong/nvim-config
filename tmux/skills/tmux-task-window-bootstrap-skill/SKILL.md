---
name: tmux-task-window-bootstrap-skill
description: v0.1.3 - Internal helper that creates a dedicated task worktree and tmux task window, dispatches a bare orchestrator fork into it, and stops before prompt injection.
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
- stop after the bare fork command has been dispatched

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
- For this orchestrator fork, use `gpt-5.4-mini` with
  `model_reasoning_effort=xhigh` and `service_tier=fast`.
- The `codex fork` argument must be a real Codex session/thread id from
  `CODEX_SESSION_ID` or `CODEX_THREAD_ID`; never substitute a tmux session
  name such as `tender_back/dev-14`.
- Do not send the orchestrator startup prompt from this helper.
- The caller must inject the prompt explicitly with:
  `tmux send-keys -t <pane> -l "$prompt"` -> `Enter` -> `sleep 0.5` -> `Enter`.
- After prompt injection, prefer a short `tmux/bin/tmux-shared-status`
  confirmation instead of repeating the full prompt body in commentary.
- Do not inline full prompt bodies inside user-visible shell commands when
  preparing orchestrator startup prompts.
- Stop the parent agent after the fork succeeds.

## Workflow

1. Validate `repo_root`, `task_kind`, and `task_slug`.
2. Resolve `base_branch`, `branch`, `worktree_root`, and `worktree_path`.
3. Create the worktree if it does not already exist.
4. Create or verify the tmux task window for that worktree.
5. Fork the current Codex session into that tmux window using the lightweight
   orchestrator profile (`gpt-5.4-mini`, `xhigh`, `fast`).
6. If `tmux-orch` is available, initialize or refresh durable state.
   If it is unavailable, continue in tmux-only degraded mode rather than
   blocking task ownership.
7. Verify:
   - `window_exists=yes`
   - `window_name` is known
   - `window_id` is known or resolvable
   - `fork_status=fork-dispatched`
   - `handoff_ready=no`
8. Stop. The caller must send the orchestrator prompt explicitly in a separate
   step.

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
