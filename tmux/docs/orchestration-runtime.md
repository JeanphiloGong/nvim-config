# Orchestration Runtime

This page records the tmux-side orchestration roles and helper scripts. It is
the local runtime guide for dispatching task windows, lanes, and handoffs.

## Skill Layers

`tmux/skills/` has public roles and internal helpers.

Public roles:

- `$tmux-project-orchestrator-skill`: project-level coordination entry. It
  manages multiple worktrees or task windows, project state, dependencies, and
  sequencing. It does not write code directly.
- `$tmux-lane-dispatch-skill`: fast path for one lane. It performs preflight
  and dispatch without entering the full task lifecycle.
- `$tmux-task-orchestrator-skill`: task-window-local role. It owns local phase,
  lane assignment, handoff, review, commit, merge-back, and closure.

Internal helpers:

- `$tmux-task-window-bootstrap-skill`: creates a task worktree and tmux window,
  then starts the bare fork.
- `$tmux-task-lane-bootstrap-skill`: starts a lane pane, registers pane id, and
  manages phase-scoped lane lifecycle.

Default usage:

1. Enter a public role.
2. Let the public role decide whether a helper is needed.
3. Load internal helpers only when the public role chooses a new worktree or
   lane.

Do not use internal helpers as the default human entrypoint.

## Helper Root

Use the configured tmux helper root instead of searching the current project:

```sh
config_home="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
tmux_bin="$config_home/tmux/bin"
```

## Runtime Wrappers

`$tmux_bin/tmux-orch-preflight`

- checks environment and capabilities
- does not create panes
- does not fork Codex
- does not write tmux-orch state

`$tmux_bin/tmux-dispatch-lane`

- performs public fast-path lane dispatch after preflight
- does not own review, commit, merge, or phase lifecycle

`$tmux_bin/tmux-task-window-bootstrap`

- creates a task worktree and tmux task window
- registers initial state when `tmux-orch` is available
- starts a bare `codex fork`
- leaves prompt injection to the caller

`$tmux_bin/tmux-task-lane-bootstrap`

- creates a lane pane
- registers the pane
- starts a bare `codex fork`
- continues in tmux-only degraded mode when `jq` or `$tmux_bin/orch` is missing

`$tmux_bin/tmux-task-project-handoff`

- sends deterministic upward handoff from a task window
- reports `merge-ready`, `merge-complete`, `blocked`, or `needs-policy`
  by canonical `pane_id`

`$tmux_bin/tmux-shared-status`

- writes short status messages into the shared tmux status slot
- avoids echoing full prompt bodies

## Fork Boundary

Existing `<prefix> + f` and `<prefix> + F` remain generic bare
`codex fork <id>` helpers. They do not inject orchestration semantics.

`codex fork` requires a Codex session or thread id, usually from
`CODEX_SESSION_ID` or `CODEX_THREAD_ID`. Do not pass a tmux session name,
window name, pane id, or worktree name as the fork id.

For example, `tender_back/dev-14` is a tmux session name, not a forkable Codex
id.

## Examples

Fast lane dispatch:

```sh
"$tmux_bin/tmux-dispatch-lane" \
  --task-context "finish the current slice and report back review-ready or blocked"
```

Create a task window:

```sh
"$tmux_bin/tmux-task-window-bootstrap" \
  --repo-root "$(git rev-parse --show-toplevel)" \
  --task-kind bugfix \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --task-slug steps-sop-copy
```

Create a lane:

```sh
"$tmux_bin/tmux-task-lane-bootstrap" \
  --role coder \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --phase phase1
```

Send a project handoff:

```sh
"$tmux_bin/tmux-task-project-handoff" \
  --status merge-ready \
  --commit "$(git rev-parse --short HEAD)" \
  --refs-line "ISSUE: #41" \
  --note "ready for project-level merge scheduling"
```

## Agent Orchestration Pilot

`$tmux_bin/tmux-agent-orch` is the Mini Kanban orchestration pilot state
machine. It validates agent identity, task DAGs, dependency waiting, blocker
routing, handoffs, and `tick` dispatch.

This pilot remains as a CLI fallback. The product control plane and Web
dashboard live in the standalone ApiaryDeck project.

CLI fallback:

```sh
export AGENT_ORCH_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/agent-orch/mini-kanban"
"$tmux_bin/tmux-agent-orch" start --goal "validate Mini Kanban orchestration" --example mini-kanban
"$tmux_bin/tmux-agent-orch" ensure-agent --role builder
"$tmux_bin/tmux-agent-orch" tick --auto-create
"$tmux_bin/tmux-agent-orch" status --json
```

Register existing panes:

```sh
"$tmux_bin/tmux-agent-orch" register-agent --agent-id builder-1 --role builder --pane %12
"$tmux_bin/tmux-agent-orch" register-agent --agent-id tester-1 --role tester --pane %13
"$tmux_bin/tmux-agent-orch" register-agent --agent-id reviewer-1 --role reviewer --pane %14
```

Run the smoke test:

```sh
tmux/test/tmux-agent-orch-smoke.sh
```

## Related Docs

- tmux-orch state layer: [tmux-orch.md](tmux-orch.md)
- Mini Kanban pilot: [agent-orch-mini-kanban-pilot.md](agent-orch-mini-kanban-pilot.md)
- ApiaryDeck runtime: standalone ApiaryDeck checkout
