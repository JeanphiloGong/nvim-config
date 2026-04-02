# Pane And Lane Bootstrap Reference

This reference documents the pane-management capability used by
`$tmux-task-lane-bootstrap-skill` when `$tmux-task-orchestrator-skill` has
already chosen the next local action and lane plan.

This is a helper capability, not a public role.

Preferred runtime wrapper:

```bash
config_home="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
tmux_bin="$config_home/tmux/bin"
orch_bin="$tmux_bin/orch"
"$tmux_bin/tmux-task-lane-bootstrap" --role coder --task-context "..." --phase phase1
```

## Purpose

- create the pane layout for one task window
- capture canonical `pane_id` values immediately
- fork non-orchestrator panes from the current orchestrator session
- keep tmux window options and `tmux-orch` pane state aligned

## Required Rules

- use tmux `pane_id` as the only machine routing key
- treat pane titles as display only
- register each pane immediately when `tmux-orch` is in use
- in Codex TUI mode, do not add `--full-auto` to lane `codex fork` commands;
  let the parent session's current permission model carry through unless an
  explicit override is truly intended
- for coder and reviewer lanes, explicitly override the fork to `gpt-5.4`
  with `model_reasoning_effort=xhigh` so they do not inherit the lightweight
  orchestrator profile
- for issue-gate lanes, explicitly use `gpt-5.4-mini` with
  `model_reasoning_effort=xhigh` and `service_tier=fast`
- the value passed to `codex fork` must come from `CODEX_SESSION_ID` or
  `CODEX_THREAD_ID`; it is not the tmux session name
- do not embed startup prompts directly in `codex fork`
- do not send startup prompts from the bootstrap helper
- inject the prompt explicitly with the raw `tmux send-keys` sequence after the
  fork command has been dispatched
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
# orchestrator_session_id must be the real Codex UUID-like session/thread id, not `#S`.
state_root="${TMUX_ORCH_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/$(printf '%s' "$session_name" | tr '/: ' '___')}"

coder_pane="$(tmux split-window -P -F '#{pane_id}' -h -c "$worktree_path")"
issue_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"

tmux set -wq @pane_orchestrator "$orch_pane"
tmux set -wq @pane_coder "$coder_pane"
tmux set -wq @pane_issue_gate "$issue_pane"

tmux set -pt "$orch_pane" @user_pane_title "orchestrator"
tmux set -pt "$coder_pane" @user_pane_title "coder"
tmux set -pt "$issue_pane" @user_pane_title "issue-gate"

"$orch_bin" register-pane --root "$state_root" --window-id "$window_id" --pane-id "$orch_pane" --role orchestrator --scope window --status active
"$orch_bin" register-pane --root "$state_root" --window-id "$window_id" --pane-id "$coder_pane" --role coder --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"
"$orch_bin" register-pane --root "$state_root" --window-id "$window_id" --pane-id "$issue_pane" --role issue-gate --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"

printf -v coder_fork 'TMUX_ORCH_ROOT=%q codex fork %q --cd %q --no-alt-screen -m gpt-5.4 -c model_reasoning_effort=xhigh' \
  "$state_root" "$orchestrator_session_id" "$worktree_path"
printf -v issue_fork 'TMUX_ORCH_ROOT=%q codex fork %q --cd %q --no-alt-screen -m gpt-5.4-mini -c model_reasoning_effort=xhigh -c service_tier=fast' \
  "$state_root" "$orchestrator_session_id" "$worktree_path"
tmux send-keys -t "$coder_pane" "$coder_fork" C-m
tmux send-keys -t "$issue_pane" "$issue_fork" C-m
```

## Prompt Injection

After the pane exists and the bare fork command has been sent, inject the lane
prompt explicitly:

```bash
message="$(printf 'You are the coder lane for this task window.\nThe task plan is already decided by $tmux-task-orchestrator-skill.\nRole: coder\nWindow id: %s\nYour pane id: %s\nOrchestrator pane id: %s\nState root: %s\nBefore returning control, refresh your pane status if needed, send a structured handoff message to the orchestrator pane, and append the same handoff to tmux-orch.\nReport changed files, checks run, risks, and a clear request for the next action.' \"$window_id\" \"$coder_pane\" \"$orch_pane\" \"$state_root\")"
tmux send-keys -t "$coder_pane" -l "$message"
tmux send-keys -t "$coder_pane" Enter
sleep 0.5
tmux send-keys -t "$coder_pane" Enter
```

Recommended lane prompt contract for every created pane:

- state that the pane was dispatched by `$tmux-task-orchestrator-skill`
- include the concrete role name
- include `window_id`, current `pane_id`, `orchestrator_pane_id`, and
  `TMUX_ORCH_ROOT`
- include the current phase and task context
- require a final structured handoff back to the orchestrator pane
- require a matching `"$orch_bin" handoff` append when `tmux-orch` is in use
- require the lane to refresh its own pane record via `"$orch_bin" register-pane`
  when status changes to values such as `active`, `blocked`, or `idle`

Suggested lane-specific prompts:

```text
Coder:
You are the coder lane for this task window. $tmux-task-orchestrator-skill has
already decided the current plan. Do not redefine scope. Implement only the
assigned slice, run the smallest relevant checks, then send a structured
handoff back to the orchestrator and append the same handoff to tmux-orch.

Issue-Gate:
You are the issue-gate lane for this task window. Confirm issue traceability,
draft or refine the issue when needed, and return a structured handoff with the
issue outcome, refs line, and whether human confirmation is still needed. Also
append the same handoff to tmux-orch.

Reviewer:
You are the reviewer lane for this task window. Review findings first, do not
edit implementation unless explicitly reassigned, and hand back one of
approved/fix-now/follow-up with concrete findings. Also append the same handoff
to tmux-orch.
```

## Reviewer Startup

Create a fresh reviewer pane when formal review is needed:

```bash
reviewer_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"
tmux set -wq @pane_reviewer "$reviewer_pane"
tmux set -pt "$reviewer_pane" @user_pane_title "reviewer"
"$orch_bin" register-pane --root "$state_root" --window-id "$window_id" --pane-id "$reviewer_pane" --role reviewer --scope phase --phase phase1 --status active --forked-from-session-id "$orchestrator_session_id"
```

## Handoff Pattern

```bash
message="$(printf '[handoff][coder->orchestrator]\nstatus: review-ready\nchanged_files: app/service.py\nchecks_run: pytest -q\nrisks: none\nrequest: dispatch reviewer')"
tmux send-keys -t "$orch_pane" -l "$message"
tmux send-keys -t "$orch_pane" Enter

"$orch_bin" handoff \
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

If the lane updates its own runtime state, use the same identifiers when
refreshing pane status:

```bash
"$orch_bin" register-pane \
  --root "$state_root" \
  --window-id "$window_id" \
  --pane-id "$coder_pane" \
  --role coder \
  --scope phase \
  --phase phase1 \
  --status active \
  --forked-from-session-id "$orchestrator_session_id"
```
