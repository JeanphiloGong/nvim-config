---
name: task-worktree-bootstrap-skill
description: v0.1.0 - Create a dedicated git worktree for every code task, open the initial task window, fork the current session into that workspace, and hand off immediately to the task-window orchestrator.
---

# Task Worktree Bootstrap Skill

## Trigger and Scope

Use this skill before any code task (`feat`, `fix`, `refactor`, `chore`).

This skill is required when a task will modify source code, configs, or tests.
Do not use it for discussion-only or docs-only work unless a branch workspace is still desired.

## Core Purpose

- Force isolation: every code task starts in a new worktree.
- Keep current workspace clean for review and integration.
- Use the operator's current branch as the default baseline unless `base_branch` is explicitly overridden.
- Reduce accidental cross-task contamination.
- If inside tmux, open a new tmux window in the new worktree path.
- Treat a successful fork into the new worktree as the normal completion state.
- Hand off execution in the new worktree before any implementation begins.
- Hand off the context needed for downstream pane and window state registration
  without becoming the durable owner of that state.

## Required Inputs

- `repo_root`: absolute repository root path.
- `task_kind`: one of `feat|fix|refactor|chore`.
- `task_slug`: lowercase kebab-case task id.

## Optional Inputs

- `base_branch`: default current checked out branch at `repo_root`; if `HEAD` is detached, require an explicit value.
- `worktree_root`: default `<repo_root>/../_worktrees`.

## Optional Environment Inputs

- `WORKTREE_AUTO_TMUX_WINDOW`: `1|0`, default `1`.
- `WORKTREE_TMUX_WINDOW_NAME`: optional primary worktree window name.
- `WORKTREE_FORK_CODEX`: `1|0`, default `1`; fork current Codex session into the new primary tmux window.
- `WORKTREE_FORK_PROMPT`: optional fork prompt override; default must instruct the forked session to start with `task-window-orchestrator-skill` rather than direct implementation.
- `WORKTREE_CURRENT_TASK`: task context text; when present, enables child-agent preparation.
- `WORKTREE_AUTO_SUBAGENT`: `1|0`, default `1`.
- `WORKTREE_SUBAGENT_PROMPT`: optional child-agent prompt override.
- `WORKTREE_SUBAGENT_WINDOW_NAME`: optional child-agent tmux window name.

## Fixed Defaults

- `isolation_policy=always-new-worktree`
- `base_branch_policy=current-branch-unless-overridden`
- `cleanup_policy=manual-retain`
- `bootstrap_method=manual-commands`
- `tmux_auto_window=enabled`
- `codex_fork_mode=required-primary-window`
- `subagent_mode=optional-async`
- `branch_pattern=task/<task_kind>/<yyyymmdd>-<task_slug>`
- `path_pattern=<worktree_root>/<task_kind>-<task_slug>`

## Guardrails

- Never start code edits in the current workspace when this skill is triggered.
- Never create worktree directories inside `repo_root`.
- Block if target branch already exists.
- Block if target worktree path already exists.
- Do not auto-delete worktrees after completion.
- Do not rewrite history.
- Do not start direct implementation in the forked session before the handoff prompt is processed.
- Child-agent auto-start requires explicit task context (`WORKTREE_CURRENT_TASK`).
- Do not auto-modify shell `PATH` on each run.
- If `fork_status=started-primary-window`, parent agent must stop this turn after reporting handoff.
- Do not let bootstrap become the durable state owner for downstream
  `tmux-orch` registration; hand off repo, worktree, and window context instead.

## Common Failure Modes and Fixes

### 1. tmux window was created but "disappears"

Cause:
- Using `tmux new-window ... "<one-shot command>"` will close the window as soon as that command exits.
- This is easy to hit when running `codex fork ...` directly as the window command.

Fix:
- Prefer opening a plain shell window first, then inject the fork command with `tmux send-keys`.
- If a one-shot command must be used, keep the shell alive afterward with `; exec bash`.

Recommended pattern:

```bash
tmux new-window -d -t <session> -n <window_name> -c <worktree_path>
tmux send-keys -t <session>:<window_name> \
  "codex fork <session_id> \"<prompt>\" --cd \"<worktree_path>\" --full-auto --no-alt-screen" C-m
```

Fallback one-shot pattern:

```bash
tmux new-window -d -t <session> -n <window_name> -c <worktree_path> \
  "bash -lc 'codex fork <session_id> \"<prompt>\" --cd \"<worktree_path>\" --full-auto --no-alt-screen; exec bash'"
```

### 2. Nested shell quoting breaks the fork command

Cause:
- Deeply nested quoting such as `bash -lc "tmux new-window ... 'codex fork ...'"` is brittle.
- Prompts with spaces, quotes, or punctuation can produce `unexpected EOF while looking for matching` errors.

Fix:
- Avoid composing the entire bootstrap in one nested shell string when tmux + prompt text are both involved.
- Prefer the two-step `new-window` + `send-keys` flow.
- If a single command is unavoidable, store prompt and paths in variables first and expand them in one shell layer only.

Best practice:
- Treat `tmux new-window` as window creation only.
- Treat `tmux send-keys` as command dispatch only.
- Do not mix multiple quoting layers unless you have no alternative.

### 3. Sandboxed tmux inspection fails

Cause:
- In restricted environments, tmux socket access may fail with errors such as `Operation not permitted`.

Fix:
- If available, rerun tmux inspection with the required escalation/approval path.
- If escalation is not appropriate, report that window creation could not be verified from the sandbox and provide manual verification commands.

Manual verification commands:

```bash
tmux list-windows -a
tmux capture-pane -pt <session>:<window_index> -S -30
```

## Best Practices

- Prefer `new-window` + `send-keys` over a one-shot window command for any interactive tool.
- Verify success explicitly after bootstrap with `tmux list-windows -a` and confirm the pane path matches `<worktree_path>`.
- Use stable, predictable tmux window names so retries can detect and replace stale windows safely.
- When re-running bootstrap, kill or rename conflicting windows before recreating them.
- If the forked session is expected to continue unattended, use `--no-alt-screen` so scrollback and captured output remain visible.
- Report both the worktree path and the exact `tmux select-window` fallback command in the handoff.

## Recommended Task Sequence

For tracked engineering work, the default sequence is:

1. bootstrap worktree
2. fork the current session into the new worktree window
3. start `task-window-orchestrator-skill` in the forked session
4. let the window-level orchestrator establish task status, phase, and downstream pane orchestration before meaningful implementation starts
5. if the core is novel or noisy, run `reference-core-impl-skill` in the new worktree
6. use `human-core-feature-wave-skill` to land the learned core back into production code
7. finalize with downstream execution and commit-stage skills as needed

Interpretation:
- This skill owns the first boundary only: no code edits before the new worktree exists.
- The normal end state is a successful fork into the new worktree window.
- The forked session should begin by invoking `task-window-orchestrator-skill`, not by writing code directly.
- `reference-core-impl-skill` and `human-core-feature-wave-skill` assume this isolation boundary already exists when they will produce or modify code.
- Small `docs|chore|test` tasks or short exploratory spikes may follow repository policy exceptions, but they still must pass the final commit gate.

## Workflow

1. Validate inputs (`repo_root`, `task_kind`, `task_slug`).
2. Resolve `base_branch`, then compute branch name and worktree path from fixed patterns.
3. Run preflight checks:
   - repo exists and is a git worktree
   - if `base_branch` is omitted, the current branch resolves from `repo_root`
   - if `HEAD` is detached and `base_branch` is omitted, block and require an explicit `base_branch`
   - resolved base branch exists locally or on `origin`
   - target branch does not exist
   - target path does not exist
   - `worktree_root` is outside `repo_root`
   - worktree root is writable (if not writable, block and show permission/rerun hint)
4. Create the worktree branch:
   - `git -C <repo_root> worktree add -b <branch> <worktree_path> <base_branch>`
5. Detect tmux environment:
   - if `TMUX` is set and `tmux` exists, open a persistent shell window at `<worktree_path>`
6. Fork codex into the primary tmux window:
   - use `WORKTREE_FORK_CODEX=1` by default
   - if codex session id is available (`CODEX_SESSION_ID` or `CODEX_THREAD_ID`):
     - dispatch `codex fork <session_id> <prompt> --cd <worktree_path> --no-alt-screen` into the new primary window with `tmux send-keys`
     - the default prompt must explicitly instruct the forked session to start with `task-window-orchestrator-skill`
     - verify the target window exists before reporting handoff
   - if codex session id is unavailable, block and report the missing session context instead of silently downgrading the workflow
7. Optional child-agent launch after handoff:
   - if `WORKTREE_CURRENT_TASK` exists and `WORKTREE_AUTO_SUBAGENT=1`:
     - in tmux: open a second window and run `codex <prompt>` asynchronously only when the downstream orchestrator plan explicitly needs it
     - outside tmux: output a ready-to-run child-agent command (manual)
8. Print handoff commands:
   - `cd <worktree_path>` (non-tmux fallback)
   - `tmux select-window -t <window_name>` (tmux primary window)
   - `next_skill_hint: task-window-orchestrator-skill`
   - if downstream orchestration uses an external state layer, include the
     current repo, worktree, session, and window context needed for later
     `register-window`
9. If fork started in the primary window:
   - parent agent reports "fork done" and stops immediately
   - parent agent must not continue implementation or orchestration in this turn
10. Keep worktree after delivery; cleanup is manual.

## Standard Manual Flow (Recommended)

This skill's source of truth is a manual command flow.
Do not rely on repository-local helper scripts as the default path.
This skill no longer provides helper bootstrap scripts; remove or ignore any old local copies.

Recommended sequence:

```bash
repo_root="/repo"
task_kind="refactor"
task_slug="kg-enum-types"
base_branch="${BASE_BRANCH_OVERRIDE:-$(git -C "$repo_root" symbolic-ref --quiet --short HEAD)}"
if [ -z "$base_branch" ]; then
  echo "error: detached HEAD; set BASE_BRANCH_OVERRIDE explicitly" >&2
  exit 1
fi
worktree_root="$(dirname "$repo_root")/_worktrees"
branch="task/${task_kind}/$(date +%Y%m%d)-${task_slug}"
worktree_path="${worktree_root}/${task_kind}-${task_slug}"

git -C "$repo_root" worktree add -b "$branch" "$worktree_path" "$base_branch"
```

If tmux is available, create a persistent window first:

```bash
session_name="$(tmux display-message -p '#S')"
window_name="wt-${task_slug}"

tmux new-window -d -t "$session_name" -n "$window_name" -c "$worktree_path"
```

If Codex fork is required, inject it into that window instead of using a one-shot tmux command:

```bash
session_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID}}"
prompt='Continue in this new worktree as the bootstrap handoff agent. Do not start implementation directly. First inspect repo state, confirm task context, and then run $task-window-orchestrator-skill to decide task-window phase, lane ownership, and downstream pane execution order. After the task window is established, stop acting as the bootstrap agent.'

tmux send-keys -t "${session_name}:${window_name}" \
  "codex fork ${session_id} \"${prompt}\" --cd \"${worktree_path}\" --full-auto --no-alt-screen" C-m
```

Verify the window exists before reporting success:

```bash
tmux list-windows -t "$session_name" -F '#S:#I:#W:#{pane_current_path}'
```

Optional pane output check:

```bash
tmux capture-pane -pt "${session_name}:${window_name}" -S -30
```

### Worked Example: Successful Sibling Worktree Bootstrap

Use this pattern when the current repository already lives under a `_worktrees/` directory and you want the new worktree as a sibling of the current one instead of nesting another `_worktrees` directory under it.

```bash
repo_root="/repo-parent/_worktrees/feat-current-task"
base_branch="feature/current-base-branch"
task_kind="refactor"
task_slug="sample-task"
worktree_root="$(dirname "$repo_root")"
branch="task/${task_kind}/$(date +%Y%m%d)-${task_slug}"
worktree_path="${worktree_root}/${task_kind}-${task_slug}"
session_name="$(tmux display-message -p '#S')"
window_name="wt-${task_slug}"
session_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID}}"

if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
  echo "error: target branch already exists: $branch" >&2
  exit 1
fi

if [ -e "$worktree_path" ]; then
  echo "error: target worktree path already exists: $worktree_path" >&2
  exit 1
fi

git -C "$repo_root" worktree add -b "$branch" "$worktree_path" "$base_branch"
tmux new-window -d -t "$session_name" -n "$window_name" -c "$worktree_path"
prompt='Continue in this new worktree as the bootstrap handoff agent. Do not start implementation directly. First inspect repo state, confirm task context, and then run $task-window-orchestrator-skill to decide task-window phase, lane ownership, and downstream pane execution order. After the task window is established, stop acting as the bootstrap agent.'
printf -v fork_cmd 'codex fork %q %q --cd %q --full-auto --no-alt-screen' "$session_id" "$prompt" "$worktree_path"
tmux send-keys -t "${session_name}:${window_name}" "$fork_cmd" C-m
sleep 2
tmux list-windows -t "$session_name" -F '#S:#I:#W:#{pane_current_path}'
tmux capture-pane -pt "${session_name}:${window_name}" -S -30
```

This pattern works because it keeps tmux window creation and command dispatch separate, uses `printf -v ... %q` to avoid prompt quoting breakage, and verifies both the window path and pane output after the fork command is injected.

## Output Format

```
## Worktree Plan
- repo_root:
- base_branch:
- base_branch_source:
- branch:
- worktree_path:

## Preflight Checks
- repo:
- base_branch:
- branch_conflict:
- path_conflict:

## Environment Detection
- tmux_env:
- tmux_window_opened:
- tmux_window_name:

## Child Agent
- task_context_present:
- subagent_status:
- subagent_window_name:
- subagent_command:

## Codex Fork
- fork_enabled:
- fork_status:
- fork_session_source:
- fork_command:
- parent_should_stop:
- parent_stop_reason:

## Execution Commands
- git worktree add ...
- tmux new-window ... (when tmux)
- tmux send-keys ... (when forking codex)
- cd ... (fallback)

## Task Handoff
- implement_in:
- integration_note:

## Cleanup Notes
- policy: manual-retain
- cleanup_cmd: git -C <repo_root> worktree remove <worktree_path>
```
