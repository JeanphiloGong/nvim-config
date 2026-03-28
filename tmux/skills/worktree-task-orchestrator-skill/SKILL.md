---
name: worktree-task-orchestrator-skill
description: v0.1.11 - Orchestrate pane layout, role ownership, and phased execution after a bootstrapped worktree session is forked into tmux, using pane_id routing, real-newline plus double-Enter pane messaging by default, requiring newly created reviewer panes for code review, lane startup by forking from the orchestrator session, and phase-scoped non-orchestrator panes.
---

# Worktree Task Orchestrator Skill

## Trigger and Scope

Use this skill after `worktree-task-bootstrap-skill` has created a new
worktree, opened a tmux window, and forked the current session into that
workspace.

This skill is the normal next step once the forked session has landed in the
new worktree and should decide how execution is organized before direct
implementation begins.

This skill is for tracked engineering work where one tmux window should
represent one task and one worktree, while multiple pane roles may collaborate
inside that window.

In scope:
- create titled panes inside that window
- let the orchestrator assign roles such as `coder`, `issue-gate`, and
  `reviewer`
- realize the already-agreed task plan through explicit execution lanes
- maintain or emit the state needed for an external `tmux-orch` consumer when
  that state layer is part of the workflow

Out of scope:
- creating the worktree itself
- opening the initial tmux task window
- performing the initial worktree fork
- docs-only tasks
- direct implementation in the current workspace
- uncontrolled multi-writer execution
- always-on independent audit claims

## Core Purpose

- Start from the already-bootstrapped worktree boundary.
- Model one task as one tmux window with visible role lanes.
- Turn the forked session into a control-plane agent, not a direct implementer.
- Allow traceability and review work to stay near the coding lane without
  turning every task into a full committee.
- Preserve operator control with explicit pane titles and role ownership.
- Use tmux `pane_id` as the canonical machine routing target for inter-pane dispatch.
- Use pane-local `@user_pane_title` for human-visible lane labels where the tmux config supports it.
- Keep the `orchestrator` pane as the window-scoped long-lived control lane.
- Treat `coder`, `issue-gate`, and `reviewer` panes as phase-scoped lanes that
  should be recreated for each new phase.
- Keep the orchestrator in a control-plane role rather than making it the default code reviewer.
- Require a newly created dedicated `reviewer` pane whenever formal code review is needed.
- Require every newly created non-orchestrator pane to start by forking from the current orchestrator session rather than launching an unrelated new Codex session.
- Allow the orchestrator to dispatch lane-specific skills without silently replacing lane ownership.
- Reflect the default tracked-work expectation that issue existence is checked
  before meaningful implementation proceeds.

## Required Inputs

- `task_context`: concise task statement used by the orchestrator.

## Optional Inputs

- `repo_root`: inferred from current git root when needed.
- `task_kind`: inferred when needed.
- `task_slug`: inferred when needed.

## Optional Environment Inputs

- `WORKTREE_ORCH_LAYOUT`: `dual-pane|three-pane`, default `three-pane`.
- `WORKTREE_ORCH_INITIAL_ROLES`: comma-separated roles, default
  `orchestrator,coder`.
- `WORKTREE_ORCH_SECONDARY_ROLE`: `issue-gate|reviewer|none`, default `issue-gate`.
- `WORKTREE_ORCH_REVIEW_START`: `post-plan|post-diff`, default `post-diff`.
- `WORKTREE_PANE_TITLE_ORCH`: default `orchestrator`.
- `WORKTREE_PANE_TITLE_CODER`: default `coder`.
- `WORKTREE_PANE_TITLE_SECONDARY`: default derived from secondary role.
- `WORKTREE_PANE_MESSAGE_MODE`: `literal-enter|literal-double-enter`, default
  `literal-double-enter`.

## Fixed Defaults

- `isolation_policy=always-new-worktree`
- `window_policy=one-task-one-window`
- `execution_mode=orchestrated`
- `primary_role=orchestrator`
- `writer_policy=single-writer-by-default`
- `secondary_role_policy=phase-bound`
- `default_issue_lane=enabled`
- `tmux_layout_policy=explicit-pane-titles`
- `entry_policy=post-bootstrap-only`

## Role Model

### Orchestrator
- Owns the task window and pane map.
- Decides whether `issue-gate` or `reviewer` is needed.
- Keeps the agreed task plan, role boundaries, and handoff state visible.
- Is window-scoped and normally persists across multiple phases within the same task window.
- Does not become the default long-running code writer.
- Does not become the default code reviewer.
- May perform lightweight sanity checks, but formal code review belongs to the `reviewer` lane.
- May instruct other lanes to use specific skills, but should not silently execute lane-specific skill work on their behalf unless role ownership is explicitly reassigned.

### Coder
- Default implementation lane.
- Is phase-scoped and should be recreated when a new phase begins.
- Owns edits unless the orchestrator explicitly assigns disjoint write scopes.
- Reports changed files, verification, and remaining risks.

### Issue-Gate
- Pre-implementation lane only.
- Is phase-scoped and should be closed or discarded after issue status for the current phase is clear.
- Checks whether the canonical issue already exists.
- Creates the issue only when missing, preferably by invoking `issue-gate-skill`.
- Must not re-plan the task or drift into implementation.
- Must not review code.
- Should exit or go idle after issue status and commit bridge are clear.

### Reviewer
- Post-plan or post-diff lane only.
- Must run in a newly created dedicated `reviewer` pane when formal code review is required.
- Is phase-scoped and should be closed after the current review cycle completes.
- Reviews for correctness, risk, regressions, and missing validation.
- Must not be presented as independent audit unless its prompt and scope are
  explicitly review-only.

## Skill Dispatch Policy

- The orchestrator may require `coder`, `issue-gate`, or `reviewer` lanes to use
  specific skills when doing so clarifies execution boundaries.
- Skill dispatch does not change role ownership by itself.
- Newly created lane panes should inherit context by forking from the current
  orchestrator session, not by starting unrelated fresh Codex sessions.
- If a lane-specific skill is needed, prefer dispatching that skill to the
  appropriate lane instead of having the orchestrator perform the work.
- The orchestrator should only execute lane-specific skill work after an
  explicit role reassignment, and that reassignment should be visible in the
  pane map and handoff state.

## Phase Lifecycle Policy

- A task window may contain multiple sequential phases such as `phase1`,
  `phase2`, or `phase3`.
- The `orchestrator` pane is window-scoped and should usually remain alive
  across phase boundaries.
- The `coder`, `issue-gate`, and `reviewer` panes are phase-scoped.
- When a new phase begins, create fresh non-orchestrator panes for that phase
  instead of carrying old lane panes forward.
- Do not reuse a completed phase's `coder`, `issue-gate`, or `reviewer` pane
  as the active lane for the next phase.
- Close completed phase panes when practical, or at minimum remove them from the
  canonical pane map before creating the next phase's lanes.

## External State Contract

When an external `tmux-orch` state layer exists, this skill should treat that
layer as a durable audit and validation surface rather than as the primary live
routing authority.

Rules:

- live message routing still resolves through tmux `pane_id` and window-scoped
  tmux options
- durable state should record windows, panes, handoffs, and phase transitions
  without overriding live tmux routing
- handoff records should include sender and recipient `pane_id`, not only role
  strings
- phase closure should retire completed phase-scoped panes from the durable
  active map before the next phase begins
- non-orchestrator pane registration should record `forked_from_session_id`

Reference:

- `docs/tmux-orch-state-contract.md`

## Pane Communication Protocol

Pane-to-pane communication must be treated as Codex TUI input, not shell
command injection.

### Canonical Pane Identity Rule

Use tmux `pane_id` as the canonical target for any machine-routed pane
communication or lane startup.

Use pane titles only for human traceability, never as the sole routing key.

Preferred storage model:
- store the orchestrator's pane map as window-scoped tmux options
- store one user-visible role label per pane via `@user_pane_title`

Recommended routing keys:
1. tmux `pane_id` for message targeting
2. window-scoped pane map for lane lookup
3. `@user_pane_title` for display only

Recommended pattern:

```bash
orch_pane="$(tmux display-message -p '#{pane_id}')"
coder_pane="$(tmux split-window -P -F '#{pane_id}' -h -c "$worktree_path")"
issue_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"

tmux set -wq @pane_orchestrator "$orch_pane"
tmux set -wq @pane_coder "$coder_pane"
tmux set -wq @pane_issue_gate "$issue_pane"

tmux set -pt "$orch_pane" @user_pane_title "orchestrator"
tmux set -pt "$coder_pane" @user_pane_title "coder"
tmux set -pt "$issue_pane" @user_pane_title "issue-gate"
```

### Role-First Prompt Rule

Every newly created non-orchestrator pane must receive a first message that
starts by naming the lane identity before any task instructions.

Required first-line pattern:

```text
You are the <role> lane for this task window.
```

This is mandatory for:
- `coder`
- `issue-gate`
- `reviewer`

Purpose:
- prevent a new pane from assuming it is the orchestrator
- prevent accidental replanning or role drift
- make ownership explicit from the first line of execution

Required pattern:

1. build the message with real newline characters
2. send literal text
3. send `Enter` separately
4. by default, send a second `Enter` after a short delay

Use:

```bash
message="$(printf 'line1\nline2\nline3')"
tmux send-keys -t "<pane_target>" -l "$message"
tmux send-keys -t "<pane_target>" Enter
sleep 0.2
tmux send-keys -t "<pane_target>" Enter
```

Do not use:

```bash
message='line1\nline2\nline3'
tmux send-keys -t "<pane_target>" -l "$message"
```

Do not use:

```bash
tmux send-keys -t "<pane_target>" "<message>" C-m
```

Reason:
- `-l` sends raw text without tmux key-name interpretation
- a separate `Enter` is closer to human interaction with the Codex TUI
- a second delayed `Enter` is more reliable in panes where a single `Enter`
  may be interpreted as newline insertion before submit
- `printf` produces real newline characters; a quoted `\n` string will often
  be rendered literally instead of as multiple lines

### Required Status Messages

The orchestrator owns the canonical pane state and should require explicit lane
notifications.

Minimum status protocol:
- `issue-gate -> orchestrator` when issue status is known
- `coder -> orchestrator` when implementation starts
- `coder -> orchestrator` when a reviewable diff or verification result exists
- `orchestrator -> reviewer` when review should begin
- `reviewer -> orchestrator` when findings are ready
- `orchestrator -> coder` when fixes or follow-up are required

### Suggested Message Templates

Issue gate result:

```text
[handoff][issue-gate->orchestrator]
status: issue-checked
issue_result: <reused | created | blocked>
issue_ref: <ISSUE: #id | none>
notes: <short note>
```

Coder ready for review:

```text
[handoff][coder->orchestrator]
status: review-ready
changed_files: <paths>
checks_run: <commands or none>
risks: <top risks>
request: dispatch reviewer
```

Orchestrator dispatches reviewer:

```text
[handoff][orchestrator->reviewer]
task: review current implementation
focus: correctness, regressions, missing validation
artifacts: <changed files / diff summary / checks>
response_format: findings-first
```

Reviewer returns findings:

```text
[handoff][reviewer->orchestrator]
status: review-complete
findings: <top findings or none>
open_risks: <remaining risks>
recommendation: <fix-now | acceptable-with-risk | needs-human-decision>
```

## Role Prompt Templates

In the normal bootstrap path, the current session is already the orchestrator.
Do not inject a second "become orchestrator" prompt into the same pane.

### Coder Prompt Template

Use when dispatching the coder lane:

```text
You are the coder lane for this task window. The task plan is already decided; do not redesign scope. Execute the assigned changes conservatively, respect existing user edits, and keep to the agreed file scope. Report changed files, checks run, and remaining risks back to the orchestrator. When a reviewable diff exists, send a handoff message to the orchestrator instead of self-approving.
```

### Issue-Gate Prompt Template

Use when dispatching the issue lane:

```text
You are the issue-gate lane for this task window. Do not plan the task and do not write production code. Check whether the canonical tracking issue already exists for the agreed task. If it exists, return the issue reference. If it does not exist, create it using `issue-gate-skill` with a concise, execution-ready task framing. After issue status is clear, report the result and commit bridge back to the orchestrator, then go idle.
```

### Reviewer Prompt Template

Use when dispatching the reviewer lane:

```text
You are the reviewer lane for this task window. Review the coder's output against the already-agreed task plan. Focus on correctness, regressions, missing validation, and scope drift. Do not rewrite the plan and do not become an implementation lane. Return findings-first feedback to the orchestrator.
```

## Guardrails

- Do not use this skill unless tmux is available or the operator accepts manual
  non-tmux fallback commands.
- Do not modify the current workspace.
- Do not create worktree directories inside `repo_root`.
- Do not launch more than three panes by default.
- Do not assign two writing lanes to the same files unless the operator
  explicitly approves disjoint write scopes.
- Do not run `issue-gate` and `reviewer` as one undifferentiated long-lived
  pane role.
- Do not use the issue lane for planning; the plan should already be decided
  before this skill starts execution.
- Do not let the orchestrator act as the default code reviewer.
- If code review is required, create a new dedicated `reviewer` pane before
  review begins instead of routing review through the orchestrator or the
  `issue-gate` lane.
- Do not repurpose an `issue-gate` pane into a `reviewer` pane.
- Do not carry `coder`, `issue-gate`, or `reviewer` panes across phase
  boundaries as if they were still the active lanes for the new phase.
- Every newly created non-orchestrator pane must receive a role-first prompt as
  its first message.
- Do not claim independent review when all panes inherit the same starting
  context unless the reviewer lane is tightly constrained.
- Pane titles are mandatory.
- In environments that expose pane labels through `@user_pane_title`, prefer
  that field over tmux built-in `pane_title` for human-visible lane names.
- All machine-targeted inter-pane messaging must target tmux `pane_id`, not a
  pane title string.
- Do not start a newly created lane pane with a brand-new unrelated Codex
  session; fork it from the current orchestrator session instead.
- Do not encode multiline inter-pane messages with a literal `\n` string.
- Inter-pane Codex messages must use `tmux send-keys -l ...` followed by a
  separate `Enter`, and the default mode should send a second delayed `Enter`.
- Do not treat pane titles, pane indexes, or stale durable snapshots as routing
  truth when live tmux `pane_id` state is available.

## Recommended Task Sequence

1. start from the bootstrapped worktree window
2. inspect task context and current repo state
3. create and title the initial pane layout
4. let the orchestrator choose minimal active roles
5. if needed, dispatch the `coder` lane
6. run `issue-gate` before implementation starts unless the operator explicitly
   selects `secondary_role=none`
7. if needed, run `reviewer` only after a plan or diff exists
8. finalize with issue traceability checks and commit preparation

Interpretation:
- This skill owns both the isolation boundary and the initial execution
  topology.
- The orchestrator chooses the smallest useful role set for the task while
  treating the task plan as already decided.
- `issue-gate` is enabled by default because tracked work should confirm issue
  existence before implementation.
- `reviewer` is late-bound by default, but once formal code review is needed it
  should run in a newly created dedicated reviewer pane rather than through the
  orchestrator.
- Across phase boundaries, keep the `orchestrator` pane and recreate the other
  lane panes.
- This skill should be entered by the forked bootstrap session before any
  implementation-heavy lane starts.

## Workflow

1. Validate inputs and confirm the session is already inside the intended
   worktree.
2. Inspect repo state and task context.
3. Detect tmux environment:
   - this skill assumes the bootstrap flow has already opened the task window
4. Build the pane layout:
   - `dual-pane`: `orchestrator` + `coder`
   - `three-pane`: `orchestrator` + `coder` + one phase-bound secondary pane
   - default layout is `three-pane` with `issue-gate` as the secondary role
5. Capture each newly created pane's tmux `pane_id` immediately.
6. Store a canonical pane map as window-scoped tmux options.
7. Set pane titles immediately after creation.
8. Start each newly created non-orchestrator pane by forking from the current
   orchestrator session into that pane.
9. Immediately send a role-first prompt to each newly created non-orchestrator
   pane.
10. If an external `tmux-orch` state layer exists, register the task window and
    each pane as they become active, including fork provenance for
    non-orchestrator panes.
11. Establish one canonical pane map and role plan:
   - the current session is already the orchestrator
   - assign roles conservatively and avoid multi-writer overlap
12. Optional secondary lane startup:
   - `issue-gate` starts by default and may run only before coding begins
   - `reviewer` may start only after a plan or diff exists unless explicitly
     overridden
   - when review starts, create a separate reviewer pane before any review
     dispatch occurs
13. When panes need to communicate, send messages with real-newline text plus
    separate-Enter protocol, always targeting a resolved `pane_id`.
14. Default to a second delayed `Enter` for inter-pane submission unless the
    current terminal interaction has already proven single-Enter reliable.
15. Print handoff commands:
   - `tmux select-window -t <window_name>`
   - pane titles and current role plan
16. Dispatch downstream roles and monitor phase changes.
17. When the phase completes, close or retire the phase-scoped panes and create
    fresh ones for the next phase while keeping the orchestrator pane.

## Standard Manual Flow (Recommended)

```bash
session_name="$(tmux display-message -p '#S')"
window_name="$(tmux display-message -p '#W')"
worktree_path="$(pwd)"
orch_pane="$(tmux display-message -p '#{pane_id}')"
orchestrator_session_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID}}"
coder_pane="$(tmux split-window -P -F '#{pane_id}' -h -t "${session_name}:${window_name}.0" -c "$worktree_path")"
issue_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"

tmux set -wq @pane_orchestrator "$orch_pane"
tmux set -wq @pane_coder "$coder_pane"
tmux set -wq @pane_issue_gate "$issue_pane"

tmux set -pt "$orch_pane" @user_pane_title "orchestrator"
tmux set -pt "$coder_pane" @user_pane_title "coder"
tmux set -pt "$issue_pane" @user_pane_title "issue-gate"

printf -v coder_fork_cmd 'codex fork %q %q --cd %q --full-auto --no-alt-screen' \
  "$orchestrator_session_id" \
  "You are the coder lane for this task window." \
  "$worktree_path"
printf -v issue_fork_cmd 'codex fork %q %q --cd %q --full-auto --no-alt-screen' \
  "$orchestrator_session_id" \
  "You are the issue-gate lane for this task window." \
  "$worktree_path"

tmux send-keys -t "$coder_pane" "$coder_fork_cmd" C-m
tmux send-keys -t "$issue_pane" "$issue_fork_cmd" C-m
```

Default third pane for the issue lane:

```bash
tmux set -pt "$issue_pane" @user_pane_title "issue-gate"
```

Suggested issue-gate lane startup message:

```bash
message="$(printf 'You are the issue-gate lane for this task window. Do not plan the task and do not write production code. Check whether the canonical tracking issue already exists for the agreed task. If it exists, return the issue reference. If it does not exist, create it using `issue-gate-skill` with a concise, execution-ready task framing. After issue status is clear, report the result and commit bridge back to the orchestrator, then go idle.')"
tmux send-keys -t "$issue_pane" -l "$message"
tmux send-keys -t "$issue_pane" Enter
sleep 0.2
tmux send-keys -t "$issue_pane" Enter
```

Suggested coder lane startup message:

```bash
message="$(printf 'You are the coder lane for this task window. The task plan is already decided; do not redesign scope. Execute the assigned changes conservatively, respect existing user edits, and keep to the agreed file scope. Report changed files, checks run, and remaining risks back to the orchestrator. When a reviewable diff exists, send a handoff message to the orchestrator instead of self-approving.')"
tmux send-keys -t "$coder_pane" -l "$message"
tmux send-keys -t "$coder_pane" Enter
sleep 0.2
tmux send-keys -t "$coder_pane" Enter
```

Suggested reviewer lane startup message:

```bash
reviewer_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$coder_pane" -c "$worktree_path")"
tmux set -wq @pane_reviewer "$reviewer_pane"
tmux set -pt "$reviewer_pane" @user_pane_title "reviewer"
printf -v reviewer_fork_cmd 'codex fork %q %q --cd %q --full-auto --no-alt-screen' \
  "$orchestrator_session_id" \
  "You are the reviewer lane for this task window." \
  "$worktree_path"
tmux send-keys -t "$reviewer_pane" "$reviewer_fork_cmd" C-m
message="$(printf 'You are the reviewer lane for this task window. Review the coder'\''s output against the already-agreed task plan. Focus on correctness, regressions, missing validation, and scope drift. Do not rewrite the plan and do not become an implementation lane. Return findings-first feedback to the orchestrator.')"
tmux send-keys -t "$reviewer_pane" -l "$message"
tmux send-keys -t "$reviewer_pane" Enter
sleep 0.2
tmux send-keys -t "$reviewer_pane" Enter
```

Recommended pane-message pattern after forks are live:

```bash
orch_pane="$(tmux show -wgv @pane_orchestrator)"
message="$(printf '[handoff][coder->orchestrator]\nstatus: review-ready\nchanged_files: app/service.py tests/test_service.py\nchecks_run: pytest tests/test_service.py -q\nrisks: none\nrequest: dispatch reviewer')"
tmux send-keys -t "$orch_pane" -l "$message"
tmux send-keys -t "$orch_pane" Enter
sleep 0.2
tmux send-keys -t "$orch_pane" Enter
```

Single-Enter fallback, only after the current pane pair has already proven
reliable submission behavior:

```bash
orch_pane="$(tmux show -wgv @pane_orchestrator)"
message="$(printf '[handoff][coder->orchestrator]\nstatus: review-ready\nchanged_files: app/service.py tests/test_service.py\nchecks_run: pytest tests/test_service.py -q\nrisks: none\nrequest: dispatch reviewer')"
tmux send-keys -t "$orch_pane" -l "$message"
tmux send-keys -t "$orch_pane" Enter
```

Verify window and pane titles:

```bash
tmux list-panes -t "${session_name}:${window_name}" -F '#S:#I.#P #{?@user_pane_title,#{@user_pane_title},-} #{pane_current_path}'
tmux capture-pane -pt "$orch_pane" -S -30
```

## Output Format

```
## Task Window
- repo_root:
- worktree_path:
- tmux_window_name:

## Session Checks
- repo:
- in_worktree:
- tmux_ready:

## Pane Map
- layout:
- pane_titles:
- orchestrator_pane:
- coder_pane:
- secondary_pane:
- secondary_role:

## Role Plan
- active_roles:
- writer_lane:
- issue_lane_status:
- review_lane_phase:

## Messaging Protocol
- pane_message_mode:
- handoff_rules:
- review_trigger:

## Execution Commands
- tmux split-window -P -F '#{pane_id}' ...
- tmux set -wq @pane_<role> ...
- tmux set -pt <pane_id> @user_pane_title ...
- tmux send-keys -t <pane_id> ...

## Task Handoff
- task_window:
- coder_in:
- orchestrator_in:
- pane_selection_hint:
- integration_note:
```
