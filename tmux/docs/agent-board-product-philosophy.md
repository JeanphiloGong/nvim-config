# ApiaryDeck Product Philosophy

ApiaryDeck is the long-term product name for the AgentBoard direction in this
tmux toolset.

The current implementation can continue to expose `AgentBoard` as the Neovim
command and UI surface while the broader product idea is recorded as
ApiaryDeck. `AgentBoard` names the current board view; `ApiaryDeck` names the
larger human-centered agent control system this work is growing toward.

## Naming Decision

Use **ApiaryDeck** for the product direction.

The name combines two ideas:

- `Apiary`: a managed place where many hives can operate at once.
- `Deck`: the human operator's control surface.

This is more precise than `Hive` for this project. A hive suggests the agents
are the main organism. An apiary suggests a human-managed system of many hives.
The deck makes the operator position explicit: the user is not another agent
inside the swarm; the user is above the swarm, watching, directing, and
intervening.

Avoid using `OpenApiary` as the primary name. It carries the right values of
openness and observability, but it is easy to misread as an OpenAPI-related
tool. Those values should live in the product description instead of the name.

## Design Center

ApiaryDeck is human-centered agent orchestration.

The system should help one person manage a powerful group of agents without
giving the group hidden autonomy. The user should only need to work directly
with a small number of top-level agents, while still being able to inspect any
worker agent, jump to its pane, intervene, redirect it, or stop it.

The core promise is:

```text
All agent work is observable, interruptible, and adjustable by the human.
```

This differs from systems that optimize mainly for stronger autonomous agents.
ApiaryDeck optimizes for stronger human control over many agents.

## Vocabulary

Use this vocabulary when extending docs, UI labels, or future connector
concepts:

- **Operator**: the human user. The operator has final authority.
- **Deck**: the control surface where the operator observes and acts.
- **Apiary**: the whole managed environment of agent work.
- **Hive**: one workspace, project, or session-scale group of related agents.
- **Cell**: one execution slot, usually a tmux pane or equivalent connector
  target.
- **Crown agent**: a top-level agent the operator talks to directly.
- **Worker agent**: a delegated agent doing a narrower task.
- **Signal**: hook or connector data that describes goal, plan, state,
  evidence, blockers, and outcome.
- **Connector**: an integration layer for tmux, Codex, Claude, OpenCode, or
  another runtime.

Do not make "queen" a first-class agent role. The useful idea is that the
human occupies the command seat. Turning that into a Queen agent would weaken
the human-centered model and make the control path less clear.

## Product Principles

ApiaryDeck should preserve these principles:

- Human authority is explicit. The system suggests, routes, and displays; the
  user decides when to create agents, send prompts, resume sessions, or commit
  work.
- Top-level control stays small. The user should be able to coordinate through
  a few crown agents instead of micromanaging every worker by default.
- Worker activity stays inspectable. Any agent can be selected, previewed,
  jumped to, resumed, redirected, or stopped.
- State is explained in management language. The UI should show goal, plan,
  current focus, evidence, next step, blocker, and outcome before raw enum
  fields.
- Runtime routing stays concrete. tmux panes, Codex sessions, cwd, and process
  state remain available as implementation facts, but they are not the main
  user-facing language.
- Automation is opt-in. Expensive, destructive, or agent-spawning actions need
  an explicit user trigger.
- Connectors should not hide control. A future non-tmux connector must still
  expose enough routing and status data for the operator to understand and
  intervene.

## Current Mapping

The current tmux implementation maps naturally to the ApiaryDeck model:

- `prefix + C` / `:AgentBoard`: opens the deck.
- tmux session or window: acts like a hive.
- tmux pane: acts like a cell.
- Codex, Claude, OpenCode, Gemini, or Copilot process: acts like an agent in a
  cell.
- Codex hooks and `tmux-agent-brief`: provide signals.
- `tmux-agent-scan`: reads the live apiary topology.
- `J`: jumps from the deck into a selected cell.
- `i`: sends operator input to a selected cell.
- restore report: lets the operator explicitly resume interrupted cells.

This mapping should guide future renames without forcing an immediate code
rename. The implementation can keep `agentboard` and `AgentBoard` while docs
and future product language use ApiaryDeck for the broader system.

## Boundaries

ApiaryDeck should not become an opaque autonomous planner.

It should not:

- create or resume agents without user action
- hide worker prompts, outputs, or routing targets
- replace engineering lifecycle skills with UI guesses
- commit, ship, or run destructive commands on behalf of the user without a
  clear confirmation path
- make tmux-specific assumptions part of the product model when they belong to
  the tmux connector

It should:

- make coordination state visible
- give the user fast routes into any agent
- preserve enough history to understand why an agent is in its current state
- make delegation and recovery explicit
- support future connectors without weakening observability

## Relationship To Existing Docs

The current `AgentBoard` docs remain implementation docs for the tmux-backed
board, manager brief, restore flow, and orchestration console.

This page records the product philosophy and naming decision that should guide
future work. When a later change renames commands, files, or public APIs, that
change should have its own implementation plan and migration notes.
