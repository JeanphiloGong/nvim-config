# Task Orchestrator Manual Flow

Use this reference when `$tmux-task-orchestrator-skill` needs the concrete
shell sequence for window registration or merge-ready handoff.

## Bootstrap The Current Task Window

```bash
session_name="$(tmux display-message -p '#S')"
session_slug="$(printf '%s' "$session_name" | tr '/: ' '___')"
window_name="$(tmux display-message -p '#W')"
window_id="$(tmux display-message -p '#{window_id}')"
worktree_path="$(pwd)"
branch="$(git -C "$worktree_path" branch --show-current)"
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/${session_slug}}"

if command -v jq >/dev/null 2>&1 && [ -x tmux/bin/orch ]; then
  tmux/bin/orch init --root "$state_root"
  tmux/bin/orch register-window \
    --root "$state_root" \
    --window-id "$window_id" \
    --window-name "$window_name" \
    --worktree-path "$worktree_path" \
    --branch "$branch" \
    --task "$task_context" \
    --phase "phase1" \
    --status "in_progress" \
    --next-action "confirm-task-context" \
    --review-status "pending" \
    --commit-status "pending" \
    --merge-status "not_ready"

  tmux/bin/orch status --root "$state_root"
else
  printf 'tmux-orch unavailable; continuing in tmux-only degraded mode\n'
fi
```

## Merge-Ready Handoff

If lanes are required after local confirmation, follow
`$tmux-task-lane-bootstrap-skill`. When coder or reviewer hand back a result,
record the handoff and update the task window's next decision before
dispatching more work. When the task reaches `merge-ready`, hand it upward
with:

```bash
tmux/bin/tmux-task-project-handoff \
  --root "$state_root" \
  --status merge-ready \
  --commit "$(git rev-parse --short HEAD)" \
  --refs-line "ISSUE: #41" \
  --note "ready for project-level merge scheduling"
```
