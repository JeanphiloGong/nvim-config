"""Run with python3 tools/learning-wiki/test_wiki.py; no real API calls."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import threading
import unittest
from unittest.mock import patch

import wiki


def concept(slug="go-booleans", related=None, body="Both operands must be true for `a && b` to be true."):
    return {"id": slug, "title": "Go boolean expressions", "body": body, "related": related or []}


class WikiTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="learning wiki ")
        self.root = Path(self.temp.name)
        self.vault = self.root / "Learning Wiki"
        self.home = self.root / "codex"
        self.home.mkdir()
        self.requests = []
        self.output = {"concepts": [concept()]}
        self.status = "completed"
        self.http_status = 200
        self.on_request = None
        owner = self

        class Provider(BaseHTTPRequestHandler):
            def do_POST(self):
                owner.requests.append((self.path, self.headers["Authorization"],
                                       json.loads(self.rfile.read(int(self.headers["Content-Length"])))))
                if owner.on_request:
                    owner.on_request()
                self.send_response(owner.http_status)
                self.end_headers()
                self.wfile.write(json.dumps({
                    "status": owner.status,
                    "output": [{"type": "message", "content": [{"type": "output_text", "text": json.dumps(owner.output)}]}],
                }).encode())

            def log_message(self, *_):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Provider)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        (self.home / "config.toml").write_text(
            'model_provider = "fixture"\n[model_providers.fixture]\nwire_api = "responses"\n'
            f'base_url = "http://127.0.0.1:{self.server.server_port}/v1"\nenv_key = "WIKI_TEST_KEY"\n')
        self.env = patch.dict(os.environ, {"WIKI_TEST_KEY": "fixture-secret"})
        self.env.start()
        self.snapshot = wiki.Snapshot(str(self.root / "source with spaces.md"),
                                      "# Explain example.go:1-3\n\n```go\nreturn a && b\n```\n\nBoth must be true.  \n\n\n", (100, 1))

    def tearDown(self):
        self.env.stop()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def test_structured_request_and_canonical_ids(self):
        result = wiki.extract(self.snapshot, {"go-booleans": "Boolean logic in Go"}, self.home)
        self.assertEqual(result[0].title, "Boolean logic in Go")
        path, auth, request = self.requests[0]
        self.assertEqual(path, "/v1/responses")
        self.assertEqual(auth, "Bearer fixture-secret")
        self.assertEqual(request["model"], "gpt-6.1-terra")
        self.assertEqual(request["reasoning"], {"effort": "none"})
        self.assertFalse(request["stream"])
        self.assertFalse(request["store"])
        self.assertTrue(request["text"]["format"]["strict"])
        self.assertEqual(json.loads(request["input"][0]["content"])["source"], self.snapshot.content)
        self.assertIn("Always write English", request["instructions"])

    def test_invalid_concepts(self):
        for item in [concept("../escape"), concept(related=["unknown"]), concept(related=["go-booleans"]),
                     concept(body="<!-- learning-wiki:injection -->"), concept(body="[file](../../file.md)")]:
            with self.subTest(item=item), self.assertRaises(RuntimeError):
                wiki.parse_concepts({"concepts": [item]}, {})
        with self.assertRaises(RuntimeError):
            wiki.parse_concepts({"concepts": [concept(), concept()]}, {})

    def test_incomplete_provider(self):
        self.status = "incomplete"
        with self.assertRaisesRegex(RuntimeError, "did not complete"):
            wiki.extract(self.snapshot, {}, self.home)

    def test_snapshot_boundaries(self):
        source = self.root / "real.md"
        source.write_text(self.snapshot.content)
        actual = wiki.Snapshot.from_file(source)
        self.assertEqual(actual.content, self.snapshot.content)
        self.assertEqual(actual.version, divmod(source.stat().st_mtime_ns, 1_000_000_000))
        payload = {"path": actual.path, "content": actual.content, "version": list(actual.version)}
        self.assertEqual(wiki.Snapshot.from_payload(payload), actual)
        for changed in [{"path": "../relative.md"}, {"version": [1, 1_000_000_000]}, {"content": ""}]:
            with self.subTest(changed=changed), self.assertRaises(RuntimeError):
                wiki.Snapshot.from_payload(payload | changed)

    def test_linked_pages_duplicate_and_stale(self):
        self.output = {"concepts": [concept(related=["go-errors"]), concept("go-errors")]}
        result = wiki.ingest(self.snapshot, self.vault, self.home)
        self.assertEqual(result["status"], "updated")
        page = self.vault / "Concepts/go-booleans.md"
        self.assertIn("[Go boolean expressions](go-errors.md)", page.read_text())
        self.assertIn(self.snapshot.content, (self.vault / result["source"]).read_text())
        before = {path: path.read_bytes() for path in self.vault.rglob("*.md")}
        self.assertEqual(wiki.ingest(self.snapshot, self.vault, self.home)["status"], "unchanged")
        stale = wiki.Snapshot(self.snapshot.path, "Old answer", (99, 0))
        self.assertEqual(wiki.ingest(stale, self.vault, self.home)["status"], "stale")
        self.assertEqual(len(self.requests), 1)
        self.assertEqual(before, {path: path.read_bytes() for path in self.vault.rglob("*.md")})
        for path, data in before.items():
            for target in wiki.re.findall(r"\]\(([^)]+)\)", data.decode()):
                if not target.startswith("file:"):
                    self.assertTrue((path.parent / target).is_file(), (path, target))
        newer = wiki.Snapshot(self.snapshot.path, self.snapshot.content, (102, 0))
        self.assertEqual(wiki.ingest(newer, self.vault, self.home)["status"], "unchanged")
        self.assertEqual(len(self.requests), 1)
        state = json.loads((self.vault / ".learning-wiki/state.json").read_text())
        self.assertEqual(state["sources"][self.snapshot.id]["version"], [102, 0])

    def test_follow_up_preserves_manual_edits_and_other_sources(self):
        wiki.ingest(self.snapshot, self.vault, self.home)
        another = wiki.Snapshot(str(self.root / "another.md"), "# Another explanation\nBoolean example.", (101, 0))
        wiki.ingest(another, self.vault, self.home)
        page = self.vault / "Concepts/go-booleans.md"
        original = page.read_text()
        page.write_text("My handwritten opening.\n\n" + original + "\nMy handwritten ending.\n")
        source = self.vault / "Sources" / self.snapshot.note
        source.write_text(source.read_text() + "\nMy source annotation.\n")
        index = self.vault / "Learning.md"
        index.write_text("My learning goals.\n\n" + index.read_text())
        self.on_request = lambda: page.write_text(page.read_text() + "Edited during inference.\n")
        self.output = {"concepts": [concept(body="Updated explanation including the follow-up clarification.")]}
        follow_up = wiki.Snapshot(self.snapshot.path, self.snapshot.content + "\n## Follow-up\nA clarification.\n", (102, 2))
        wiki.ingest(follow_up, self.vault, self.home)
        text = page.read_text()
        self.assertTrue(text.startswith("My handwritten opening.\n\n"))
        self.assertTrue(text.endswith("My handwritten ending.\nEdited during inference.\n"))
        self.assertEqual(text.count("<!-- learning-wiki:source:" + self.snapshot.id + ":start -->"), 1)
        self.assertIn("Updated explanation", text)
        self.assertIn("<!-- learning-wiki:source:" + another.id, text)
        self.assertIn("My source annotation.", source.read_text())
        self.assertTrue(index.read_text().startswith("My learning goals."))
        self.assertIn("go-booleans", json.loads(self.requests[-1][2]["input"][0]["content"])["catalog"])

    def test_removed_concept_only_removes_its_source_section(self):
        wiki.ingest(self.snapshot, self.vault, self.home)
        page = self.vault / "Concepts/go-booleans.md"
        page.write_text(page.read_text() + "My own explanation stays.\n")
        self.output = {"concepts": []}
        wiki.ingest(wiki.Snapshot(self.snapshot.path, "# Revised source\n", (102, 0)), self.vault, self.home)
        self.assertIn("My own explanation stays.", page.read_text())
        self.assertNotIn("<!-- learning-wiki:source:", page.read_text())

    def test_invalid_model_output_and_http_error_do_not_write_notes(self):
        self.output = {"concepts": [concept("../../escape")]}
        with self.assertRaises(RuntimeError):
            wiki.ingest(self.snapshot, self.vault, self.home)
        self.assertEqual(list(self.vault.rglob("*.md")), [])
        self.http_status = 503
        with self.assertRaises(wiki.urllib.error.HTTPError):
            wiki.ingest(self.snapshot, self.vault, self.home)
        self.assertFalse((self.vault / ".learning-wiki/state.json").exists())

    def test_concurrent_cli_import_keeps_source_unchanged_and_calls_api_once(self):
        path = self.root / "a real record.md"
        path.write_text(self.snapshot.content)
        original = path.read_bytes()
        command = [sys.executable, str(Path(wiki.__file__)), "--vault", str(self.vault), "--codex-home", str(self.home), str(path)]
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: subprocess.run(command, capture_output=True, text=True, timeout=15), range(2)))
        self.assertTrue(all(result.returncode == 0 for result in results), [result.stderr for result in results])
        self.assertEqual({json.loads(result.stdout)["status"] for result in results}, {"updated", "unchanged"})
        self.assertEqual(len(self.requests), 1)
        self.assertEqual(path.read_bytes(), original)

    def test_version_conflicts_and_edited_delimiters_do_not_overwrite_notes(self):
        wiki.ingest(self.snapshot, self.vault, self.home)
        before = {path: path.read_bytes() for path in self.vault.rglob("*.md")}
        conflict = wiki.Snapshot(self.snapshot.path, "Different content", self.snapshot.version)
        with self.assertRaisesRegex(RuntimeError, "same version"):
            wiki.ingest(conflict, self.vault, self.home)
        self.assertEqual(len(self.requests), 1)
        self.assertEqual(before, {path: path.read_bytes() for path in self.vault.rglob("*.md")})
        page = self.vault / "Concepts/go-booleans.md"
        page.write_text(page.read_text().replace(f"<!-- learning-wiki:source:{self.snapshot.id}:end -->", "My accidental edit"))
        before = {path: path.read_bytes() for path in self.vault.rglob("*.md")}
        state = (self.vault / ".learning-wiki/state.json").read_bytes()
        follow_up = wiki.Snapshot(self.snapshot.path, self.snapshot.content + "More explanation.", (103, 0))
        with self.assertRaisesRegex(RuntimeError, "markers were edited"):
            wiki.ingest(follow_up, self.vault, self.home)
        self.assertEqual(before, {path: path.read_bytes() for path in self.vault.rglob("*.md")})
        self.assertEqual(state, (self.vault / ".learning-wiki/state.json").read_bytes())

    def test_cli_provider_errors_hide_credentials_and_response_body(self):
        self.http_status = 503
        self.output = {"private": "fixture-secret private-provider-diagnostic"}
        payload = {"path": self.snapshot.path, "content": self.snapshot.content, "version": list(self.snapshot.version)}
        result = subprocess.run([sys.executable, str(Path(wiki.__file__)), "--vault", str(self.vault),
                                 "--codex-home", str(self.home)], input=json.dumps(payload),
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertIn("HTTP 503", result.stderr)
        self.assertNotIn("fixture-secret", result.stderr + result.stdout)
        self.assertNotIn("private-provider-diagnostic", result.stderr + result.stdout)
        self.assertEqual(list(self.vault.rglob("*.md")), [])
        config = self.home / "config.toml"
        config.write_text(config.read_text().replace(f"http://127.0.0.1:{self.server.server_port}/v1", "private-provider.invalid"))
        result = subprocess.run([sys.executable, str(Path(wiki.__file__)), "--vault", str(self.vault),
                                 "--codex-home", str(self.home)], input=json.dumps(payload),
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("private-provider.invalid", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
