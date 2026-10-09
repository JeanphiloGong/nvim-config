"""Exercise production notify with real isolated tmux/ps and fixture threads."""

import json
import os
from pathlib import Path
import shlex
import sqlite3
import subprocess
import tempfile
import time


NOTIFY = Path(__file__).resolve().parents[1] / "bin/codex-tmux-notify"
PARENT = "01a00000-0000-7000-8000-000000000001"
CHILD_A = "01a00000-0000-7000-8000-000000000002"
CHILD_B = "01a00000-0000-7000-8000-000000000003"


def main():
    with tempfile.TemporaryDirectory(prefix="notify-routing-") as directory:
        root = Path(directory)
        socket = root / "tmux.sock"

        def tmux(*args):
            return subprocess.check_output(
                ["tmux", "-S", str(socket), *args], text=True
            ).strip()

        def cache(pane):
            return tmux("show", "-pqv", "-t", pane, "@codex_pane_thread_id")

        def set_cache(pane, thread):
            tmux("set", "-p", "-t", pane, "@codex_pane_thread_id", thread)

        def emit(thread):
            tmux("set", "-g", "@codex_last_pane", "unchanged")
            env = dict(os.environ, TMUX=f"{socket},{server},0", TMUX_PANE=a,
                       CODEX_HOME=directory, CODEX_SQLITE_HOME=directory)
            subprocess.run(
                ["bash", str(NOTIFY), json.dumps({"thread-id": thread})],
                env=env, check=True, start_new_session=True,
                stdin=subprocess.DEVNULL, timeout=20,
            )
            return tmux("show", "-gqv", "@codex_last_pane")

        with sqlite3.connect(root / "state_5.sqlite") as db:
            db.execute("CREATE TABLE threads (id TEXT, rollout_path TEXT, cwd TEXT)")
            for thread in (CHILD_A, CHILD_B):
                rollout = root / f"{thread}.jsonl"
                rollout.write_text(json.dumps({"payload": {
                    "id": thread, "forked_from_id": PARENT,
                }}) + "\n")
                db.execute("INSERT INTO threads VALUES (?, ?, ?)",
                           (thread, str(rollout), directory))

        # Controlled argv, not actual Codex/model calls. tmux and ps are real.
        command = "bash -c " + shlex.quote(f'exec -a "codex fork {PARENT}" sleep 300')
        try:
            a = tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                     "-c", directory, "-P", "-F", "#{pane_id}", command)
            server = tmux("display", "-p", "#{pid}")
            tmux("set", "-g", "@codex_notify_mode", "off")
            tmux("set", "-g", "@codex_history_file", str(root / "history"))
            set_cache(a, PARENT)
            time.sleep(0.2)
            assert emit(CHILD_A) == a and cache(a) == CHILD_A
            print("PASS: unique parent fallback")

            b = tmux("split-window", "-h", "-t", a, "-c", directory,
                     "-P", "-F", "#{pane_id}", command)
            time.sleep(0.2)
            set_cache(a, CHILD_A)
            set_cache(b, CHILD_B)
            assert emit(CHILD_B) == b, "parent fallback stole exact child match"
            assert cache(a) == CHILD_A and cache(b) == CHILD_B
            assert emit(CHILD_A) == a
            print("PASS: exact child matches in both pane orders")

            set_cache(a, PARENT)
            set_cache(b, PARENT)
            assert emit(CHILD_B) == "unchanged", "ambiguous parent must not route"
            assert cache(a) == PARENT and cache(b) == PARENT
            print("PASS: ambiguous parent leaves state untouched")

            set_cache(a, CHILD_B)
            set_cache(b, CHILD_B)
            assert emit(CHILD_B) == "unchanged", "duplicate child cache must not route"
            print("PASS: duplicate child cache leaves state untouched")
        finally:
            if socket.exists():
                subprocess.run(["tmux", "-S", str(socket), "kill-server"], check=False)


if __name__ == "__main__":
    main()
