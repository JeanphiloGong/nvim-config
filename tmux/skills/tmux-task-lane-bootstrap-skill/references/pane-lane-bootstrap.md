# Pane And Lane Bootstrap Reference

This reference documents the pane-management capability used by
`$tmux-task-lane-bootstrap-skill` when `$tmux-task-orchestrator-skill` has
already chosen the next local action and lane plan.

This is a helper capability, not a public role.

## Purpose

- create the pane layout for one task window
- capture canonical `pane_id` values immediately
- fork non-orchestrator panes from the current orchestrator session
- send role-first startup prompts
- keep tmux window options and `tmux-orch` pane state aligned

## Required Rules

- use tmux `pane_id` as the only machine routing key
- treat pane titles as display only
- register each pane immediately when `tmux-orch` is in use
- in Codex TUI mode, do not add `--full-auto` to lane `codex fork` commands;
  let the parent session's current permission model carry through unless an
  explicit override is truly intended
- use a dedicated reviewer pane for formal review
- recreate phase-scoped panes across phase boundaries

## Canonical Pattern

```bash
session_name="$(tmux display-message -p '#S')"
window_name="$(tmux display-message -p '#W')"
window_id="$(tmux display-message -p '#{window_id}')"
worktree_path="$(pwd)"
orch_pane="$(tmux display-message -p '#{pane_id}')"
orchestrator_session_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID}}"
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/$(printf '%s' "$session_name" | tr '/: ' '___')}"

coder_pane="$(tmux split-window -P -F '#{pane_id}' -h -c "$worktree_path")"
issue_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"

tmux set -wq @pane_orchestrator "$orch_pane"
tmux set -wq @pane_coder "$coder_pane"
tmux set -wq @pane_issue_gate "$issue_pane"

tmux set -pt "$orch_pane" @user_pane_title "orchestrator"
tmux set -pt "$coder_pane" @user_pane_title "coder"
tmux set -pt "$issue_pane" @user_pane_title "issue-gate"

tmux/bin/orch register-pane --root "$state_root" --window-id "$window_id" --pane-id "$orch_pane" --role orchestrator --scope window --status active
tmux/bin/orch register-pane --root "$state_root" --window-id "$window_id" --pane-id "$coder_pane" --role coder --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"
tmux/bin/orch register-pane --root "$state_root" --window-id "$window_id" --pane-id "$issue_pane" --role issue-gate --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"
```

## Role-First Startup Messages

Every non-orchestrator pane should begin with:

```text
You are the <role> lane for this task window.
```

Suggested send pattern:

```bash
message="$(printf 'You are the coder lane for this task window.\nThe task plan is already decided. Execute conservatively, report changed files, checks run, and risks back to the orchestrator.')"
tmux send-keys -t "$coder_pane" -l "$message"
tmux send-keys -t "$coder_pane" Enter
sleep 0.2
tmux send-keys -t "$coder_pane" Enter
```

## Reviewer Startup

Create a fresh reviewer pane when formal review is needed:

```bash
reviewer_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"
tmux set -wq @pane_reviewer "$reviewer_pane"
tmux set -pt "$reviewer_pane" @user_pane_title "reviewer"
tmux/bin/orch register-pane --root "$state_root" --window-id "$window_id" --pane-id "$reviewer_pane" --role reviewer --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"
```

## Handoff Pattern

```bash
message="$(printf '[handoff][coder->orchestrator]\nstatus: review-ready\nchanged_files: app/service.py\nchecks_run: pytest -q\nrisks: none\nrequest: dispatch reviewer')"
tmux send-keys -t "$orch_pane" -l "$message"
tmux send-keys -t "$orch_pane" Enter
sleep 0.2
tmux send-keys -t "$orch_pane" Enter

tmux/bin/orch handoff \
  --root "$state_root" \
  --window-id "$window_id" \
  --from-pane-id "$coder_pane" \
  --to-pane-id "$orch_pane" \
  --from-role coder \
  --to-role orchestrator \
  --type review-ready \
  --payload-json '{"changed_files":["app/service.py"],"checks_run":["pytest -q"]}'
```

`$tmux-task-orchestrator-skill` should convert each such handoff into an explicit
`next_action`.
