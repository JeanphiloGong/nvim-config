# Codex Notify And Jump Back

This tmux integration helps when Codex CLI runs in one pane while you work in
another. Codex `notify` updates the tmux status line, records recent Codex
panes, and lets you jump back quickly.

## What It Provides

- Codex turn completion updates the second status line:
  `Codex: <session:window> | <summary?>`.
- The summary is read from the notify JSON when possible.
- Pane border labels are disabled by default; thread tracking and recovery remain enabled.
- The current pane gets `@codex_pane_summary`.
- The current pane gets `@codex_pane_thread_id` for future fork actions.
- Recent completions are stored in `~/.tmux-codex-history`.
- A background worker schedules Codex snapshots to `~/.tmux-codex-resume`
  on a 5-second loop, without overlapping scans. Saved panes are restored
  with their matching `codex resume <thread-id>` command after
  tmux-resurrect recreates the layout.

Language Coach also writes to the shared status slot; the latest event wins.

## Key Bindings

- `<prefix> + J`: jump to the most recently completed Codex pane.
- `<prefix> + M` on Linux, or `<prefix> + C` on WSL: open the
  `Agents / Codex / Orch` menu.
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

Persisted internal agents are excluded using the database `source.subagent`
marker (including multi-agent v2). Their completion notifications must not
replace a pane's CLI thread, activity, or history. A normal `codex fork` remains
eligible: `forked_from_id` alone does not identify an internal agent.

For shared-server notifications without a usable terminal, the hook searches
all panes for a unique exact child-thread cache before considering a unique
`codex fork <parent>` process match. Multiple exact matches or multiple parent
candidates leave pane state, history, and completion status untouched. Parent
lineage alone cannot distinguish concurrent forks of the same conversation.
Existing incorrect caches need explicit correction; this routing rule cannot
prove that an old cache belongs to the process still running in that pane.

The fork helper intentionally leaves the new pane's thread cache empty until
its first completed turn. The CLI creates the child ID internally but does not
return it to the shell helper; retaining the parent ID would make a subsequent
fork repeat the parent's history.

Run `python3 tmux/test/codex-tmux-notify-routing.py` to check this routing with
an isolated real tmux server and real process lookup. Thread data and process
arguments are fixtures; this test does not make Codex model requests.

Python 3 with SQLite support is required. The database directory is
`CODEX_SQLITE_HOME`, or `CODEX_HOME` (default `~/.codex`) when unset. If Codex uses
a custom `sqlite_home` configuration, export the matching `CODEX_SQLITE_HOME`
before starting Codex. This check targets Codex's current `state_5.sqlite`
schema; a future schema change requires updating the hook, not guessing from
session filenames.

On a machine with no saved Codex state, let one turn finish in the source pane
to initialize the cache and history. After switching conversations, the cache
may still refer to the previous conversation until the new turn completes.
Codex itself determines whether the selected thread can be forked; the name
index and rollout filename layout are not used as validity checks.

## Resurrect And Continuum Recovery

Both tmux profiles configure tmux-resurrect to restore a foreground `codex`
process and tmux-continuum to restore the saved layout automatically. During
the post-save-layout hook, each Codex pane's session/window/pane position and
thread id are recorded in `~/.tmux-codex-resurrect-state`, and its saved
process command is rewritten to `codex resume <thread_id>`. The post-restore
hook maps those positions to the newly created panes, verifies each thread in
`state_5.sqlite` and its rollout file, then rebuilds
`@codex_pane_thread_id`, `@codex_last_win`, `@codex_last_pane`, and
`@codex_last_thread_id`.

This cache rebuild is separate from the notify history file. It means `f`, `F`,
and `J` remain available immediately after a successful restore; an invalid or
deleted Codex thread is skipped rather than reintroduced into tmux state.

## Restart Recovery

The Linux and WSL tmux profiles already enable tmux-resurrect and tmux-continuum.
Both profiles start one `bin/tmux-status-worker` per tmux server. It schedules
`bin/codex-tmux-resurrect snapshot` every 5 seconds, skipping a tick while a
previous scan is running. A socket-specific file lock prevents duplicate workers
when reloading the configuration or attaching multiple clients. The worker exits
when its server exits. It checks continuum once per minute; the configured
15-minute layout-save interval still applies.

The status bar only displays tmux options: the worker samples CPU/RAM and Git
for visible client panes every 10 seconds. A pane or project switch displays its
cached Git status until the next sample. Git queries time out after 5 seconds.
CPU usage is measured between samples; RAM uses total minus available memory.
This avoids spawning shell jobs from status redraws. Run
`python3 tmux/test/tmux-status-worker-smoke.py` to verify worker ownership,
metrics, recovery scheduling, and shutdown using an isolated server.
The snapshot records the logical `session:window.pane` location and only keeps a
thread when the pane is still running Codex and Codex's `state_5.sqlite` row and
rollout file still exist. For a running Codex process, it can refresh the pane
cache before the first completion notification. Stale pane-local ids are
ignored after Codex exits. Pane ids such as `%17` are intentionally not
persisted because tmux assigns new ids after a server restart.

Lock discovery examines all thread locks, filters out internal agents, and
updates the cache only when exactly one eligible thread remains. Snapshot save
and restore also validate the database `source` field. The resurrect layout
writer clears unvalidated Codex commands instead of persisting an internal
agent's `codex resume` command. Missing database metadata fails closed.

Already saved resurrect layouts are not automatically repaired on restore:
resurrect executes their process commands before the post-restore hook. After
correcting a polluted pane cache, save a fresh layout with `<prefix> + Ctrl-s`
before restarting tmux. These checks do not change shared Codex daemon feature
settings; an incompatible daemon may still require choosing "Run without
daemon this time" in Codex.

After resurrect restores the panes, its post-restore hook sends
`codex resume <thread-id>` to each saved Codex pane. A pane that is already
running Codex is left untouched, and missing or invalid thread records are
skipped. A new snapshot is created by the background worker, so closing a
Codex pane removes it from the next recovery set.

### New Server Activation

No extra recovery plugin or helper link is required. On a machine where this
repository, the selected tmux profile, TPM, tmux-resurrect, and tmux-continuum
are already installed, update the checkout and reload tmux:

```sh
git -C "$HOME/.config/nvim" pull
tmux source-file "$HOME/.tmux.conf"
```

On a fresh machine, first link the correct Linux or WSL profile and install the
TPM plugins as described in `../README.md`. Start Codex inside tmux, wait for a
worker scan, and confirm that the snapshot and hooks are active:

```sh
test -s "$HOME/.tmux-codex-resume"
test "$(stat -c %a "$HOME/.tmux-codex-resume")" = 600
tmux show-options -gv @resurrect-hook-post-restore-all
```

The five-second snapshot stores thread mappings; tmux-continuum still saves the
full pane layout at its configured 15-minute interval. Recovery data is local
to the machine. Pulling this repository does not migrate another server's
`~/.codex` database, rollout files, tmux layout, or active sessions, and copying
`~/.tmux-codex-resume` alone is insufficient.

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
5. Press `<prefix> + M` on Linux or `<prefix> + C` on WSL and confirm the
   recent Codex pane appears in the menu.

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
