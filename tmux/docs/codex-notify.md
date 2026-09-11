# Codex Notify And Jump Back

This tmux integration helps when Codex CLI runs in one pane while you work in
another. Codex `notify` updates the tmux status line, records recent Codex
panes, and lets you jump back quickly.

## What It Provides

- Codex turn completion updates the second status line:
  `Codex: <session:window> | <summary?>`.
- The summary is read from the notify JSON when possible.
- Pane borders can show `index | user label | Codex summary`.
- The current pane gets `@codex_pane_summary`.
- The current pane gets `@codex_pane_thread_id` for future fork actions.
- Recent completions are stored in `~/.tmux-codex-history`.

Language Coach also writes to the shared status slot; the latest event wins.

## Key Bindings

- `<prefix> + J`: jump to the most recently completed Codex pane.
- `<prefix> + M`: open the `Agents / Codex / Orch` menu.
- `<prefix> + f`: split right and run `codex fork <id>` from the current pane.
- `<prefix> + F`: split down and run `codex fork <id>` from the current pane.

The fork helper reads `CODEX_THREAD_ID`. If the
current foreground process does not expose this value, it tries nearby process
state and finally the pane-local `@codex_pane_thread_id`.

The fork id must be a real Codex session or thread id. A tmux session name,
window name, pane id, or worktree name is not a valid `codex fork` id.
`CODEX_SESSION_ID` identifies a shared root session and is not used for fork.
The notify hook records the event's `thread-id`, never an inherited environment
id or generic `id` field. Before changing any pane state, it checks the thread's
record in `state_5.sqlite` and verifies that the recorded rollout path exists.
Ephemeral recap threads are not persisted and cannot replace the main thread's
cached id, summary, or notification history. Missing ids, unavailable databases,
and missing rollout files leave existing state untouched.

Python 3 with SQLite support is required. The database directory is
`CODEX_SQLITE_HOME`, or `CODEX_HOME` (default `~/.codex`) when unset. If Codex uses
a custom `sqlite_home` configuration, export the matching `CODEX_SQLITE_HOME`
before starting Codex. This check targets Codex's current `state_5.sqlite`
schema; a future schema change requires updating the hook, not guessing from
session filenames.

After upgrading these helpers, let a turn finish in the source pane to refresh
its cached id. Before the first notification, or after switching conversations,
the cache may be missing or still refer to the previous conversation. Codex
itself determines whether the selected thread can be forked; the name index and
rollout filename layout are not used as validity checks.

## Install

Place the notify script somewhere stable:

```sh
mkdir -p ~/.local/bin
ln -sf "$HOME/.config/nvim/tmux/bin/codex-tmux-notify" ~/.local/bin/codex-tmux-notify
chmod +x ~/.local/bin/codex-tmux-notify
```

Edit `~/.codex/config.toml` and add the notify hook in the global area before
any `[projects."..."]` section:

```toml
notify = ["/home/<you>/.local/bin/codex-tmux-notify"]
```

Codex does not expand `~` or `$HOME` in TOML, so use an absolute path. Restart
Codex CLI after editing the config.

## Verify

1. Start Codex in tmux.
2. Let one turn finish.
3. Confirm the second status line updates to `Codex: ...`.
4. Press `<prefix> + J` to jump back to the completed pane.
5. Press `<prefix> + M` and confirm the recent Codex pane appears in the menu.

## History Menu

The menu records recent completions by thread id. Newer entries appear first.
Each row includes:

```text
pane title | thread id | tmux location | summary
```

Configurable tmux options:

```tmux
set -g @codex_history_limit 12
set -g @codex_notify_mode off
set -g @codex_notify_mode message
set -g @codex_notify_mode popup
set -g @codex_popup_corner br
set -g @codex_popup_margin 1
set -g @codex_popup_width 60
set -g @codex_popup_height 6
set -g @codex_popup_duration 2
```

`off` is the recommended notify mode because it keeps feedback in the shared
status slot without interrupting input.

## Troubleshooting

If jump-back cannot find the pane, the most common cause is using a different
tmux server, such as `tmux -L <name>`.

Different sessions inside the same tmux server are supported. The helper first
switches client session, then selects the recorded window and pane.

For fork diagnosis:

```sh
tmux show -gv @codex_fork_last_source
tmux show -gv @codex_fork_last_pid
tmux show -gv @codex_fork_last_key
tmux show -gv @codex_fork_last_detail
tmux show -pv -t "$TMUX_PANE" @codex_pane_thread_id
```

Fork attempts are logged to `~/.tmux-codex-fork.log` by default. Set
`@codex_fork_log_file` to `off` to disable the log. `HIT` means the fork command
was sent, not that Codex accepted it.

## Related Docs

- tmux entrypoint: [../README.md](../README.md)
