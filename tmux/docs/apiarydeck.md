# ApiaryDeck Runtime

ApiaryDeck is the long-term agent orchestration direction for this tmux
toolset. The current implementation still exposes `AgentBoard` as the Neovim
UI, while ApiaryDeck names the broader human-centered control system.

The core runtime direction is SDK-first:

- Codex SDK threads and turns are the canonical agent execution record.
- tmux is an optional connector for terminal display, jump, and takeover.
- AgentBoard remains the current deck UI for inspecting and controlling work.

## Local Entry

The local helper is:

```sh
tmux/bin/apiarydeck
```

Use a state root outside the repository:

```sh
export APIARYDECK_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/apiarydeck/demo"
```

## SDK Dry Run

`sdk-run --dry-run` validates agent records, task payloads, skill payloads, and
turn event logs without requiring the Python Codex SDK to be installed:

```sh
tmux/bin/apiarydeck sdk-run \
  --agent-id crown-1 \
  --role crown \
  --task-id T1 \
  --task "plan the next implementation slice" \
  --skill workflow-plan:/path/to/workflow-plan/SKILL.md \
  --dry-run

tmux/bin/apiarydeck status
```

## Crown Orchestration

`orchestrate` starts or dry-runs a Crown orchestration agent. Its role prompt
states that it owns the goal, task graph, worker dispatch, blockers, handoffs,
and final review.

```sh
tmux/bin/apiarydeck orchestrate \
  --goal "ship a tiny SDK orchestration MVP" \
  --skill workflow-plan:/path/to/workflow-plan/SKILL.md \
  --dry-run
```

Dry run writes a minimal task graph so the Web dashboard and dispatcher can be
tested against realistic state.

Non-dry-run execution uses the Python `openai_codex` SDK and converts
`--skill name:path` into SDK skill input. If the SDK or auth state is not
available, use dry run or the existing tmux connector path.

## Dashboard

ApiaryDeck includes a local dashboard server for inspecting orchestration
state. It is intentionally lightweight and uses the local state store as the
source of truth.

The dashboard is the place for:

- session and window task tables
- task board state
- agent assignment
- blockers and handoffs
- worker pane dispatch visibility
- task inspection

## Boundaries

ApiaryDeck should not hide control behind autonomous behavior.

It should:

- make agent work observable
- keep worker activity inspectable
- preserve human authority for spawning, redirecting, resuming, and committing
- keep connector details available without making them the product language

It should not:

- create or resume agents without a user-triggered action
- hide prompts, outputs, or routing targets
- replace engineering lifecycle skills with UI guesses
- commit, ship, or run destructive commands without confirmation

## Verification

Run the smoke test:

```sh
tmux/test/apiarydeck-smoke.sh
```

## Related Docs

- Product philosophy: [agent-board-product-philosophy.md](agent-board-product-philosophy.md)
- AgentBoard orchestration console: [agent-board-orchestration-console.md](agent-board-orchestration-console.md)
- Mini Kanban pilot: [agent-orch-mini-kanban-pilot.md](agent-orch-mini-kanban-pilot.md)
- tmux entrypoint: [../README.md](../README.md)
