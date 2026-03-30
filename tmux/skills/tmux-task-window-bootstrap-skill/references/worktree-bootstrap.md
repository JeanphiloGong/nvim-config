# Worktree Bootstrap Reference

This reference documents the boundary-creation capability used by
`$tmux-task-window-bootstrap-skill` when `$tmux-project-orchestrator-skill` has
already decided that a new task needs its own worktree and tmux window.

This is a helper capability, not a public role.

Preferred runtime wrapper:

```bash
tmux/bin/tmux-task-window-bootstrap --repo-root /repo --task-context "..."
```

## Purpose

- create a dedicated git worktree for the task
- create the first tmux window for that task
- fork the current Codex session into that window
- hand task-local control to `$tmux-task-orchestrator-skill`

## Guardrails

- do not start implementation before the handoff prompt is processed
- do not invent a second `tmux-orch` root if one is already in use
- keep one task per worktree and one task per task window
- in Codex TUI mode, do not add `--full-auto` to `codex fork`; it forces the
  forked session into `workspace-write` and `on-request`
- for the orchestrator fork, use `gpt-5.4-mini` with `model_reasoning_effort=xhigh`
  and `service_tier=fast`
- do not embed the orchestrator startup prompt directly in the `codex fork`
  command; send it only after fork readiness is confirmed
- do not report downstream handoff as complete until the tmux task window
  exists, the fork command has been injected, and the startup prompt has been
  sent after readiness is confirmed
- stop the parent agent after the fork succeeds

## Manual Flow

```bash
repo_root="/repo"
task_kind="refactor"
task_slug="sample-task"
base_branch="${BASE_BRANCH_OVERRIDE:-$(git -C "$repo_root" symbolic-ref --quiet --short HEAD)}"
worktree_root="$(dirname "$repo_root")/_worktrees"
branch="task/${task_kind}/$(date +%Y%m%d)-${task_slug}"
worktree_path="${worktree_root}/${task_kind}-${task_slug}"
session_name="$(tmux display-message -p '#S')"
session_slug="$(printf '%s' "$session_name" | tr '/: ' '___')"
window_name="wt-${task_slug}"
session_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID}}"
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/${session_slug}}"

git -C "$repo_root" worktree add -b "$branch" "$worktree_path" "$base_branch"
tmux new-window -d -t "$session_name" -n "$window_name" -c "$worktree_path"
prompt='Continue in this new worktree as $tmux-task-orchestrator-skill for this task. Do not start implementation directly. First confirm repo state and task context, register or refresh the task window in tmux-orch, decide the local phase and next action, and only then dispatch coder, reviewer, or issue work if needed. When lane setup is needed, use $tmux-task-lane-bootstrap-skill rather than creating panes ad hoc.'
printf -v fork_cmd 'TMUX_ORCH_ROOT=%q codex fork %q --cd %q --no-alt-screen -m gpt-5.4-mini -c model_reasoning_effort=xhigh -c service_tier=fast' \
  "$state_root" "$session_id" "$worktree_path"
tmux send-keys -t "${session_name}:${window_name}" "$fork_cmd" C-m
for _ in $(seq 1 40); do
  [ "$(tmux display-message -p -t "${session_name}:${window_name}" '#{pane_current_command}')" = "codex" ] && break
  sleep 0.25
done
tmux send-keys -t "${session_name}:${window_name}" -l "$prompt"
tmux send-keys -t "${session_name}:${window_name}" Enter
```

## Prompt Contract

The bootstrap prompt sent after fork readiness should always include:

- the fact that the child session is now acting as `$tmux-task-orchestrator-skill`
- the task context and current repo/worktree target
- the rule that implementation must not start before local confirmation
- the requirement to register or refresh the task window in `tmux-orch`
- the requirement to choose an explicit local `next_action`
- the rule that lane realization must go through `$tmux-task-lane-bootstrap-skill`

## Handoff Data

After bootstrap, the new task window should know at least:

- `repo_root`
- `worktree_path`
- `session_name`
- `window_name`
- current `window_id` when available
- current orchestrator session id
- `state_root`

## Verification

```bash
tmux list-windows -t "$session_name" -F '#S:#I:#W:#{pane_current_path}'
tmux capture-pane -pt "${session_name}:${window_name}" -S -30
```

The helper should report success and stop only after all of the following are
true:

- `window_exists=yes`
- `window_name` is known
- `window_id` is known or can be resolved immediately
- `fork_status=ready-and-prompted`
- `handoff_ready=yes`

If the worktree exists but the tmux task window does not, bootstrap is still
incomplete and the parent role must not claim task-local ownership has already
been transferred.
