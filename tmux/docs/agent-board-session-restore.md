# Spec: AgentBoard Agent Session Restore

## Assumptions

1. This feature targets tmux-managed AI agent panes, starting with Codex.
2. The first supported restore command is Codex CLI `codex resume [SESSION_ID]`.
3. tmux may survive a terminal disconnect, but this spec targets the harder case:
   tmux server exit, machine reboot, or accidental session loss.
4. tmux-resurrect / tmux-continuum owns layout restoration. AgentBoard does not
   create replacement sessions, windows, or panes in the first version.
5. Restored tmux `pane_id` values are not stable, so durable identity cannot depend
   on `%42`-style pane ids.
6. AgentBoard should only resume agents in panes that already exist after tmux
   restore. Unresumable records are written to a log for later inspection.
7. AgentBoard should make restore suggestions and execute explicit user-triggered
   restore actions. It should not automatically restart agents after a crash.

## Objective

Add an AgentBoard recovery path that resumes Codex sessions inside panes that
tmux has already restored after an abnormal stop.

The feature should answer:

- Which agent panes existed before the stop?
- Which of those panes still exist in the current tmux server?
- Which restored panes are safe targets for `codex resume [SESSION_ID]`?
- Which Codex session should each existing pane resume?
- Which records cannot be resumed and why?

Success means the user can open AgentBoard, see a restore report, and explicitly
resume Codex sessions only in panes that already exist. Records without a safe
existing pane are logged instead of being recreated.

## Tech Stack

- tmux 3.6
- Bash for tmux wrapper commands
- Python 3 for JSON state updates and matching logic
- Lua / Neovim for AgentBoard UI integration
- Codex CLI with `codex resume [SESSION_ID] [PROMPT]`

No new external dependency should be introduced for the first implementation.

## Commands

Current verification commands:

```sh
tmux -V
codex resume --help
bash -n tmux/bin/codex-agent-status-hook tmux/bin/tmux-agent-status
python3 -m json.tool "${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json"
nvim --headless -u NONE -c "set rtp+=/home/jeanphilo/.config/nvim" -c "lua require('agent_board').setup()" -c "qa!"
```

Proposed user-facing commands:

```text
No new public shell command is required for the first version.
AgentBoard is the user-facing restore surface.
```

Proposed AgentBoard actions:

```text
R  open restore report
Enter / Space  resume selected restorable agent in its existing pane
```

## Project Structure

Expected implementation locations:

```text
tmux/bin/codex-agent-status-hook
  Records Codex thread/session id, cwd, command, target, and restore identity.

tmux/bin/tmux-agent-status
  Extends cached pane records with durable restore metadata.

tmux/bin/tmux-agent-scan
  Merges live tmux topology with restore records.

lua/agent_board.lua
  Shows restore report and routes explicit restore actions.

tmux/docs/agent-board-session-restore.md
  This spec.
```

Expected state files:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json
${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/restore/restore-log.jsonl
```

## Code Style

Shell wrappers should stay small and use direct tmux commands. Python should own
JSON reads, locking, and matching decisions.

Example restore record shape:

```json
{
  "restore_id": "codex:7f1d2c3a-6f9b-4f8e-a2ad-1c0f8df9e1f2",
  "agent": "codex",
  "codex_session_id": "7f1d2c3a-6f9b-4f8e-a2ad-1c0f8df9e1f2",
  "last_pane_id": "%42",
  "last_target": "main:2.1",
  "session_name": "main",
  "window_index": "2",
  "window_name": "nvim",
  "pane_index": "1",
  "cwd": "/home/jeanphilo/.config/nvim",
  "command": "codex",
  "goal": "完成 AgentBoard 恢复 spec",
  "updated_at": 1778755200,
  "restore_state": "missing"
}
```

Matching priority:

```text
1. Same live pane_id still exists.
2. Same codex_session_id appears in a live Codex process or pane option.
3. Same session_name + window_name/index + pane_index + cwd.
4. If the matched pane is already running Codex, do not send resume.
5. If the matched pane is an idle shell or dead/restored pane, send
   codex resume [SESSION_ID] --cd [cwd] --no-alt-screen.
6. Otherwise log the record as unresumable with a reason.
```

## Testing Strategy

Use state-file and tmux-pane smoke tests before adding UI behavior.

- Record test: create fake pane records and confirm valid JSON is written.
- Matching test: compare fake records against live `tmux list-panes` output and
  verify `alive`, `restorable-existing-pane`, `already-running`,
  `missing-pane`, and `occupied-pane` classifications.
- Restore dry-run test: verify generated `send-keys` commands without creating
  panes.
- Restore live test: with a known Codex session id, create a pane and run
  `codex resume <id> --cd <cwd> --no-alt-screen` in that existing pane.
- UI smoke test: open `:AgentBoard` headlessly and ensure restore view loads.

## Boundaries

- Always: require explicit user action before starting `codex resume`.
- Always: keep restore metadata in XDG state, not in the repository.
- Always: treat `pane_id` as volatile routing data, not durable identity.
- Always: write a log row for records that cannot be safely resumed.
- Always: only resume into an existing pane that can be matched to the old agent.
- Ask first: adding automatic periodic snapshots beyond existing hook writes.
- Ask first: integrating with `tmux-resurrect` or changing its files.
- Ask first: restoring non-Codex agents such as Claude, OpenCode, Gemini, or Copilot.
- Never: auto-run restored agents on shell startup without user confirmation.
- Never: create sessions, windows, or panes as part of the first restore version.
- Never: assume the old pane still maps to the same agent after tmux restart.
- Never: overwrite user-created live panes while restoring.

## Success Criteria

- AgentBoard reports previous agents grouped as already running, restorable in an
  existing pane, missing pane, occupied pane, and missing resume id.
- A matched existing pane with a recorded `codex_session_id` can be resumed with
  `codex resume <session-id> --cd <cwd> --no-alt-screen`.
- If the original pane still exists, restore does not start a duplicate agent.
- If the original pane is gone, restore does not create a replacement pane and
  logs the exact missing target.
- If the original pane exists but is occupied, restore does not overwrite it and
  logs the exact reason.
- AgentBoard can show the restore report without jumping into individual panes.
- Restore actions are logged to `restore-log.jsonl`.
- Existing AgentBoard scan and manager brief behavior still works when no restore
  snapshot exists.

## Open Questions

- Should snapshot timing be hook-driven only, or should there also be a periodic
  save similar to tmux-continuum?
- Should AgentBoard offer a bulk resume action for all restorable existing panes,
  or only resume one selected pane at a time?
- Should restored agents receive an initial prompt explaining that this is a
  crash recovery, or should `codex resume <id>` start silently?
- Should this feature remain AgentBoard-owned, or should it become part of the
  existing `tmux-orch` state contract later?
