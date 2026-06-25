# AgentBoard

AgentBoard is the Neovim control surface for tmux-hosted agents. It reads tmux
topology, local XDG state, and Codex hook signals, then presents session,
window, and pane state in one board.

Open it with:

```text
<prefix> + C
:AgentBoard
```

## Layout

- The board opens in a dedicated Neovim window.
- The left side is a collapsible workspace tree:
  `session -> window -> pane`.
- Session and window rows use Nerd Font icons.
- Pane rows show the detected agent type, such as Codex, Claude, OpenCode,
  Gemini, or Copilot.
- Attention states include blocked, error, stale, review-ready, working, done,
  idle, and unknown.
- Selecting a session or window shows a scope inspector.
- Selecting a pane shows a single-agent inspector and pane preview.

The right side prioritizes management language: goal, plan, current work,
evidence, next step, blocker, and outcome.

## Keys

- `j/k` or `Ctrl-h/j/k/l`: move selection.
- `Enter` / `Space`: expand a session or window.
- `gw`: expand all working agents.
- `gr`: expand all review-ready agents.
- `gd`: expand all done agents.
- `i`: send one line to the selected pane.
- `J`: jump to the selected pane.
- `O` or `0`: start an orchestration goal for the selected scope.
- `T`: dispatch the next ready task.
- `R`: open or refresh the restore report.
- `r`: rescan panes.
- `q`: close the AgentBoard window.

Preview mode:

- `j/k` or arrow keys: scroll captured pane history.
- `Esc` / `q`: return to the tree.

Mouse:

- single click selects
- double click jumps

## State Sources

AgentBoard combines these signals:

- Codex lifecycle hooks write health and work-state metadata for the current
  tmux pane.
- `tmux-agent-status` maintains the local pane state table:
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json`.
- `tmux-agent-brief` appends hook events under:
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/events/`.
- `tmux-agent-brief` asynchronously generates `headline`, `plan`, `current`,
  `evidence`, `next`, `blocked`, and `brief_outcome`.
- `tmux-agent-scan` reads tmux topology and merges it with the local state
  table.

The brief generator defaults to local rules. Optional summary backends:

```sh
export AGENT_BOARD_SUMMARY_CMD="$HOME/bin/agent-board-summarize"
export AGENT_BOARD_LLM=1
export OPENAI_API_KEY=...
export AGENT_BOARD_LLM_MODEL=gpt-5.2
export AGENT_BOARD_LLM_BASE_URL="https://api.openai.com/v1"
export AGENT_BOARD_CODEX_SUMMARY=1
```

Codex hook configuration lives in:

```text
~/.codex/hooks.json
~/.codex/config.toml
```

The Codex config must enable hooks:

```toml
[features]
hooks = true
```

New Codex sessions read this config when they start.

## Refresh Model

AgentBoard refreshes the selected right-side view frequently and rescans tmux
topology on a slower interval. Tune scan refresh from Neovim with:

```lua
vim.g.agent_board_scan_refresh_ms = 5000
```

Pane capture is used for preview and context, but high-frequency state comes
from cached records rather than repeated heavy terminal reads.

## Orchestration

From a session or window scope:

1. Press `O` or `0`.
2. Enter a goal.
3. AgentBoard initializes orchestration state and loads the Mini Kanban flow.
4. Press `T` to dispatch the next ready task.
5. Watch the task board for ready, running, waiting, blocked, done, assignment,
   blockers, and handoffs.

Worker windows should contain worker agents only. The orchestration state lives
in local XDG state and is read by AgentBoard.

## Restore

`R` opens the restore report.

AgentBoard only runs `codex resume` against panes tmux has already restored.
Unrecoverable records are written under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/restore/restore-log.jsonl
```

## Related Docs

- Install guide: [agent-board-install.md](agent-board-install.md)
- Management brief model: [agent-board-manager-brief.md](agent-board-manager-brief.md)
- Orchestration console direction: [agent-board-orchestration-console.md](agent-board-orchestration-console.md)
- Mini Kanban pilot: [agent-orch-mini-kanban-pilot.md](agent-orch-mini-kanban-pilot.md)
- Session restore spec: [agent-board-session-restore.md](agent-board-session-restore.md)
- Product philosophy: [agent-board-product-philosophy.md](agent-board-product-philosophy.md)
