"""Run with: python3 test/code-explain-api.py"""

import http.server
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "code-explain.py"


class ExplainAPITest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="code-explain-api-")
        self.home = Path(self.temp.name)
        self.release = threading.Event()
        self.mode = "success"
        self.received = None
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({"data": [{"id": "test-model"}]}).encode())

            def do_POST(self):
                owner.received = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                owner.authorization = self.headers["Authorization"]
                if owner.mode == "http-error":
                    self.send_response(401)
                    self.end_headers()
                    self.wfile.write(b'{"error":{"message":"private-provider-diagnostic"}}')
                    return
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()

                def event(payload):
                    # Exercise SSE multi-line data and an unescaped UTF-8 character.
                    lines = json.dumps(payload, indent=2, ensure_ascii=False).splitlines()
                    self.wfile.write(("\n".join("data: " + line for line in lines) + "\n\n").encode())
                    self.wfile.flush()

                if owner.mode != "empty":
                    event({"type": "response.output_text.delta", "delta": "A byte is \u00e9ight bits. "})
                if owner.mode == "hold":
                    owner.release.wait(5)
                if owner.mode == "truncated":
                    return
                if owner.mode == "failed":
                    event({"type": "response.failed", "response": {"error": {"message": "private-provider-diagnostic"}}})
                    return
                if owner.mode == "refusal":
                    event({"type": "response.refusal.delta", "delta": "Cannot answer."})
                    return
                if owner.mode != "empty":
                    event({"type": "response.output_text.delta", "delta": "The ID has 64 hex characters."})
                event({"type": "response.completed", "response": {"model": "test-model", "service_tier": "default", "usage": {}}})

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.home.joinpath("config.toml").write_text(
            'model_provider = "test"\n[model_providers.test]\n'
            f'base_url = "http://127.0.0.1:{self.server.server_port}/v1"\n'
            'env_key = "CODE_EXPLAIN_UNUSED_TEST_KEY"\n'
            'wire_api = "responses"\n'
        )
        self.home.joinpath("auth.json").write_text('{"OPENAI_API_KEY":"test-only-key"}')

    def tearDown(self):
        self.release.set()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def command(self, action="complete"):
        return [sys.executable, str(HELPER), "--codex-home", str(self.home), action]

    def request(self):
        return {"model": "test-model", "effort": "none", "instructions": "Answer in English.", "input": "Explain randomID."}

    def run_helper(self, mode="success"):
        self.mode = mode
        result = subprocess.run(self.command(), input=json.dumps(self.request()), text=True, capture_output=True, timeout=5)
        return result, [json.loads(line) for line in result.stdout.splitlines()]

    def test_stream_arrives_before_completion(self):
        self.mode = "hold"
        process = subprocess.Popen(self.command(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            process.stdin.write(json.dumps(self.request()))
            process.stdin.close()
            first = json.loads(process.stdout.readline())
            self.assertEqual(first["type"], "delta")
            self.assertIn("\u00e9ight bits", first["text"])
            self.assertIsNone(process.poll(), "The first text was buffered until process exit")
            self.release.set()
            remaining = [json.loads(line) for line in process.stdout]
            self.assertEqual(process.wait(5), 0)
            self.assertEqual(remaining[-1]["type"], "done")
        finally:
            self.release.set()
            if process.poll() is None:
                process.kill()
            process.wait()
            process.stdout.close()
            process.stderr.close()
        self.assertEqual(self.authorization, "Bearer test-only-key")
        self.assertEqual(self.received["reasoning"], {"effort": "none"})
        self.assertEqual(self.received["service_tier"], "fast")
        self.assertTrue(self.received["stream"])
        self.assertFalse(self.received["store"])
        self.assertNotIn("tools", self.received)

    def test_lists_models_from_configured_provider(self):
        result = subprocess.run(self.command("models"), text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"models": ["test-model"]})

    def test_truncated_stream_is_a_failure(self):
        result, events = self.run_helper("truncated")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events[0]["type"], "delta")
        self.assertEqual(events[-1]["type"], "error")
        self.assertNotIn("done", [event["type"] for event in events])

    def test_failed_response_does_not_expose_provider_logs(self):
        result, events = self.run_helper("failed")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events[-1]["type"], "error")
        self.assertNotIn("private-provider-diagnostic", result.stdout + result.stderr)

    def test_http_error_does_not_expose_provider_logs(self):
        result, events = self.run_helper("http-error")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("401", events[-1]["message"])
        self.assertNotIn("private-provider-diagnostic", result.stdout + result.stderr)
        self.assertNotIn("test-only-key", result.stdout + result.stderr)

    def test_empty_answer_is_a_failure(self):
        result, events = self.run_helper("empty")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events[-1]["type"], "error")

    def test_refusal_is_not_saved_as_a_successful_explanation(self):
        result, events = self.run_helper("refusal")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events[-1]["type"], "error")


if __name__ == "__main__":
    unittest.main()
