#!/usr/bin/env python3
"""Exercise singleton ownership and server lifetime without touching live tmux."""
import os
from pathlib import Path
import subprocess
import tempfile
import time

worker = Path(__file__).resolve().parents[1] / "bin/tmux-status-worker"
with tempfile.TemporaryDirectory(prefix="tmux-worker-test-") as directory:
    root = Path(directory)
    socket = str(root / "socket")
    command = ["tmux", "-S", socket]
    subprocess.run([*command, "-f", "/dev/null", "new-session", "-d"], check=True)
    server = subprocess.check_output([*command, "display-message", "-p", "#{pid}"], text=True).strip()
    env = dict(os.environ, TMUX=f"{socket},{server},0", XDG_CACHE_HOME=directory,
               TMUX_CODEX_RESURRECT_FILE=str(root / "resume"),
               TMUX_PLUGIN_MANAGER_PATH=str(Path(__file__).parent / "fixtures/tmux-worker-plugins"),
               TMUX_WORKER_TEST_SAVE=str(root / "save-check"))
    process = subprocess.Popen(["python3", str(worker)], env=env)
    try:
        for _ in range(100):
            status = subprocess.run([*command, "show-options", "-gv", "@system_status"],
                                    capture_output=True, text=True)
            if "RAM:" in status.stdout:
                break
            assert process.poll() is None, "Worker exited before publishing metrics"
            time.sleep(0.1)
        else:
            raise AssertionError("Metrics were not published")
        duplicate = subprocess.run(["python3", str(worker)], env=env, timeout=3)
        assert duplicate.returncode == 0, "Duplicate worker did not exit cleanly"
        assert process.poll() is None, "Original worker was replaced"
        for _ in range(100):
            if (root / "resume").exists():
                break
            time.sleep(0.1)
        assert (root / "resume").exists(), "Recovery snapshot did not run"
        assert (root / "save-check").read_text() == "checked\n", "Auto-save was not checked"
        subprocess.run([*command, "kill-server"], check=True)
        assert process.wait(timeout=12) == 0, "Worker outlived its server"
        print("Worker metrics, singleton, recovery scheduling, and shutdown: OK")
    finally:
        subprocess.run([*command, "kill-server"], stderr=subprocess.DEVNULL)
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
