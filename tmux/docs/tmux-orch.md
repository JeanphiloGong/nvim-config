# tmux-orch (Phase A)

`tmux-orch` is a small shell + tmux + jq state layer for Codex/tmux workflows.
It is intentionally narrow:

- skills decide policy
- tmux remains the live routing layer
- `orch` records durable state and validates cheap invariants

This Phase A prototype does not add a daemon, watcher, or planner.

## Requirements

```sh
tmux
jq
```

Install `jq`:

Ubuntu / Debian:
```sh
sudo apt update
sudo apt install -y jq
```

Fedora / RHEL / CentOS:
```sh
sudo dnf install -y jq
# Older systems may use yum:
# sudo yum install -y jq
```

Arch:
```sh
sudo pacman -S jq
```

macOS:
```sh
brew install jq
```

Verify:
```sh
jq --version
```

## State Root

Default state root:

```sh
${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/<session_name>
```

Override with:

```sh
export TMUX_ORCH_ROOT=/path/to/state
```

The prototype keeps state outside the repository so it stays portable and does
not create repo-local machine state.

Phase A intentionally scopes state by tmux session. That fits single
task-window flows where one session is the practical orchestration boundary.
If a later phase needs shared project-wide state across multiple worktrees or
task windows, add a higher-level shared root then rather than widening Phase A
by default.

## Files

```text
project-state.json
windows.json
panes.json
handoffs.jsonl
phases.jsonl
```

Current Phase A commands write `project-state.json`, `windows.json`,
`panes.json`, and `handoffs.jsonl`. `phases.jsonl` is reserved for the next
phase of the prototype.

`project-state.json` now also records the canonical project orchestrator pane:

- `project_orchestrator_window`
- `project_orchestrator_pane_id`

The handoff model is intentionally pane-first. The required core is:

- `ts`
- `window_id`
- `from_pane_id`
- `to_pane_id`
- `type`
- `payload`

Role labels and phase fields are useful metadata, but they are not the true
routing keys.

## Commands

Initialize state:

```sh
tmux/bin/orch init
```

Register the current pane as the canonical project orchestrator target:

```sh
session_name="$(tmux display-message -p '#S')"
window_id="$(tmux display-message -p '#{window_id}')"
pane_id="$(tmux display-message -p '#{pane_id}')"

tmux set-option -t "$session_name" @project_orchestrator_pane "$pane_id"
tmux/bin/orch register-project \
  --session-name "$session_name" \
  --project-orchestrator-window "$window_id" \
  --project-orchestrator-pane-id "$pane_id" \
  --current-phase phase1
```

Register the current tmux window:

```sh
tmux/bin/orch register-window \
  --task "prototype tmux-orch" \
  --phase phase1
```

Register the current pane as an orchestrator:

```sh
tmux/bin/orch register-pane \
  --role orchestrator \
  --scope window
```

Register a coder pane:

```sh
tmux/bin/orch register-pane \
  --pane-id %12 \
  --window-id @4 \
  --role coder \
  --scope phase \
  --phase phase1 \
  --forked-from-session-id "$CODEX_THREAD_ID"
```

Append a structured handoff:

```sh
tmux/bin/orch handoff \
  --from-pane-id %12 \
  --to-pane-id %10 \
  --from-role coder \
  --to-role orchestrator \
  --type review-ready \
  --payload-json '{"changed_files":["tmux/bin/orch"]}'
```

Send a deterministic task-to-project handoff:

```sh
tmux/bin/tmux-task-project-handoff \
  --status merge-ready \
  --commit "$(git rev-parse --short HEAD)" \
  --refs-line "ISSUE: #41" \
  --note "ready for project-level merge scheduling"
```

Inspect state:

```sh
tmux/bin/orch status
```

From tmux, the default Linux quick entry is the `<prefix> + M` menu. That menu
includes an `Orch dashboard` item which opens a popup view for the current
session. The WSL config still binds the same Codex / Orch menu to
`<prefix> + C`.

Validate cheap invariants:

```sh
tmux/bin/orch validate
```

Inside the popup dashboard:

- `r` refreshes the view
- `v` opens full validate output
- `q` closes the popup

## Phase Staging

Phase A command surface:

- `init`
- `register-project`
- `register-window`
- `register-pane`
- `handoff`
- `status`
- `validate`

Deferred to a later phase:

- `phase-start`
- `phase-close`
- `retire-pane`
- reviewer-specific lifecycle validation
- shared project-window state across multiple worktrees

## Validation Scope

Phase A validation stays intentionally small:

- each registered window must have exactly one active orchestrator
- active non-orchestrator panes must record `forked_from_session_id`
- panes must point to known windows
- handoffs must reference known pane ids
- if a canonical project orchestrator pane is registered, task-to-project
  handoffs must target that pane id

It does not yet manage phase close / retire or project-level dependency graphs.
It also does not yet enforce reviewer-specific invariants. Those should become
active only once formal review flow or reviewer panes are explicitly in use.

## Boundaries

- Machine routing is always by tmux `pane_id`.
- Pane titles such as `@user_pane_title` are display-only.
- State files are durable records, not a replacement for tmux runtime state.
- tmux runtime options and live dispatch remain owned by tmux and the
  orchestrator skill unless thin wrappers are added later.
- The canonical project target resolves in this order:
  - session tmux option `@project_orchestrator_pane`
  - `project-state.json.project_orchestrator_pane_id`
  - otherwise fail instead of guessing by pane index or active pane
- If the workflow later needs automation hooks or richer phase transitions, add
  them in a later phase rather than growing this prototype into a daemon.
