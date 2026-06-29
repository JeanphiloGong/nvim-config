# Agent Orchestration Mini Kanban Pilot

This legacy pilot tracks issue #39. It validates a small autonomous
orchestration loop while keeping tmux panes as execution workers. The main
product control plane has moved to the standalone ApiaryDeck project.

## Model

The runtime separates identity from terminal placement:

- `agent_id` is the logical worker identity.
- `pane_id` is the current tmux delivery target.
- `task_id` is the unit of work in the window or session task flow.
- `messages.jsonl` is the request and handoff trail.

The CLI remains available as a fallback:

```sh
tmux/bin/tmux-agent-orch start \
  --goal "validate Mini Kanban orchestration" \
  --example mini-kanban
tmux/bin/tmux-agent-orch ensure-agent --role builder
tmux/bin/tmux-agent-orch status --json
tmux/bin/tmux-agent-orch tick --auto-create
```

For an offline dry run outside tmux:

```sh
AGENT_ORCH_DRY_RUN=1 tmux/bin/tmux-agent-orch ensure-agent --role builder --dry-run
AGENT_ORCH_DRY_RUN=1 tmux/bin/tmux-agent-orch tick --auto-create --dry-run
```

Use `AGENT_ORCH_ROOT` when the state root must be shared across windows or
worktrees:

```sh
export AGENT_ORCH_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/agent-orch/mini-kanban"
```

## Example Task DAG

`load-example mini-kanban` creates this task flow:

| Task | Owner | Depends on | Expected output |
| --- | --- | --- | --- |
| T0 | builder | none | Project boots and documents dev/test commands. |
| T1 | builder | T0 | Task model and localStorage persistence are checked. |
| T2 | builder | T1 | Board UI creates and moves tasks across columns. |
| T3 | builder | T2 | Filter, edit, and delete interactions work. |
| T4 | tester | T2, T3 | Quality pass and README are complete. |
| T5 | reviewer | T4 | Final orchestration review records gaps and next steps. |

## Handoff Contract

Workers should end with a structured handoff:

```sh
tmux-agent-orch handoff \
  --task-id T1 \
  --from builder-1 \
  --status done \
  --output-json '{"changed_files":[],"checks":[],"risks":[]}'
```

If a worker is blocked, route the problem instead of guessing:

```sh
tmux-agent-orch blocker \
  --task-id T2 \
  --from builder-1 \
  --request-type missing_requirement \
  --body "Need confirmation on whether drag-and-drop is in scope."
```

Default request routing:

| Request type | Target |
| --- | --- |
| `missing_requirement` | `session-orchestrator` |
| `issue_needed` | `issue` |
| `implementation_question` | `window-orchestrator` |
| `test_failure` | `builder` |
| `review_finding` | `builder` |
| `merge_conflict` | `session-orchestrator` |
| `policy_decision` | `human` |

## Verification

Run the smoke test outside tmux:

```sh
tmux/test/tmux-agent-orch-smoke.sh
```

Manual pilot loop inside tmux:

1. Start with `start --example mini-kanban`.
2. Ensure one or more worker panes exist, or let `tick --auto-create` create them.
3. Run `tick --auto-create` to dispatch the first ready task.
4. Send a `handoff` or `blocker`.
5. Run `tick --auto-create` again and confirm dependencies advance.

The pilot succeeds when the Mini Kanban task flow can move from plan to final
review with durable task state, routed blockers, and explicit handoffs.
