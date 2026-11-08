"""Build an Obsidian-compatible learning Wiki from completed code explanations."""

import argparse
from dataclasses import dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib
import urllib.error
import urllib.request


@dataclass(frozen=True)
class Snapshot:
    path: str
    content: str
    version: tuple[int, int]

    @classmethod
    def from_payload(cls, payload):
        path, content, version = payload["path"], payload["content"], payload["version"]
        if not isinstance(path, str) or not Path(path).is_absolute() or not isinstance(content, str) or not content.strip():
            raise RuntimeError("A snapshot requires an absolute path and saved Markdown content.")
        if (not isinstance(version, list) or len(version) != 2
                or any(type(value) is not int or value < 0 for value in version) or version[1] >= 1_000_000_000):
            raise RuntimeError("A snapshot version must be [seconds, nanoseconds].")
        return cls(path, content, tuple(version))

    @classmethod
    def from_file(cls, path):
        path = path.expanduser().resolve()
        with path.open(encoding="utf-8") as source:
            before = os.fstat(source.fileno()).st_mtime_ns
            content = source.read()
            after = os.fstat(source.fileno()).st_mtime_ns
        if before != after:
            raise RuntimeError("The explanation changed while being read; retry after it finishes.")
        return cls(str(path), content, divmod(after, 1_000_000_000))

    @property
    def id(self):
        return hashlib.sha256(self.path.encode()).hexdigest()[:16]

    @property
    def note(self):
        stem = re.sub(r"[^A-Za-z0-9_-]", "-", Path(self.path).stem)[:100]
        return f"{stem}-{self.id}.md"

    @property
    def title(self):
        return next((line[2:] for line in self.content.splitlines() if line.startswith("# ")), Path(self.path).stem)


@dataclass(frozen=True)
class Concept:
    id: str
    title: str
    body: str
    related: list[str]


def parse_concepts(payload, catalog):
    if not isinstance(payload, dict) or set(payload) != {"concepts"} or not isinstance(payload["concepts"], list):
        raise RuntimeError("The model did not return a concept list.")
    if len(payload["concepts"]) > 5:
        raise RuntimeError("The model returned too many concepts for one explanation.")
    concepts = []
    for item in payload["concepts"]:
        if not isinstance(item, dict) or set(item) != {"id", "title", "body", "related"}:
            raise RuntimeError("A model concept has invalid fields.")
        slug, title, body, related = (item[field] for field in ("id", "title", "body", "related"))
        if not isinstance(slug, str) or len(slug) > 80 or not re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*", slug):
            raise RuntimeError("The model returned an unsafe concept ID.")
        if not isinstance(title, str) or not title.strip() or "\n" in title or "\r" in title:
            raise RuntimeError("A concept title must be a nonempty single line.")
        if (not isinstance(body, str) or not body.strip() or "<!-- learning-wiki:" in body
                or "](" in body or "[[" in body):
            raise RuntimeError("Concept prose must be nonempty and leave links and managed markers to the writer.")
        if not isinstance(related, list) or any(not isinstance(value, str) for value in related):
            raise RuntimeError("Related concepts must be concept IDs.")
        concepts.append(Concept(slug, catalog.get(slug, title.strip()), body.strip(), related))
    ids = {concept.id for concept in concepts}
    if len(ids) != len(concepts):
        raise RuntimeError("The model returned duplicate concept IDs.")
    for concept in concepts:
        if (concept.id in concept.related or len(set(concept.related)) != len(concept.related)
                or set(concept.related) - ids - catalog.keys()):
            raise RuntimeError("A related concept is unknown, duplicated, or refers to itself.")
    return concepts


def provider_settings(home):
    config = tomllib.loads((home / "config.toml").read_text(encoding="utf-8"))
    provider = config.get("model_providers", {}).get(config.get("model_provider", "openai"), {})
    if provider.get("wire_api", "responses") != "responses":
        raise RuntimeError("The learning Wiki requires a Responses API provider.")
    base = provider.get("base_url", "https://api.openai.com/v1").rstrip("/")
    key = os.environ.get(provider.get("env_key", "OPENAI_API_KEY"))
    if not key:
        key = json.loads((home / "auth.json").read_text(encoding="utf-8")).get("OPENAI_API_KEY")
    if not key:
        raise RuntimeError("An API key is required in the Codex provider environment or auth.json.")
    return base, key


def extract(snapshot, catalog, codex_home):
    base, key = provider_settings(codex_home)
    schema = {
        "type": "object", "additionalProperties": False, "required": ["concepts"],
        "properties": {"concepts": {
            "type": "array", "maxItems": 5, "items": {
                "type": "object", "additionalProperties": False,
                "required": ["id", "title", "body", "related"],
                "properties": {
                    "id": {"type": "string"}, "title": {"type": "string"}, "body": {"type": "string"},
                    "related": {"type": "array", "items": {"type": "string"}},
                },
            },
        }},
    }
    payload = {
        "model": "gpt-6.1-terra", "reasoning": {"effort": "none"},
        "stream": False, "store": False, "service_tier": "fast",
        "instructions": Path(__file__).with_name("prompt.md").read_text(encoding="utf-8"),
        "input": [{"role": "user", "content": json.dumps({"catalog": catalog, "source": snapshot.content})}],
        "text": {"format": {"type": "json_schema", "name": "learning_concepts", "strict": True, "schema": schema}},
    }
    request = urllib.request.Request(
        base + "/responses", data=json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        result = json.load(response)
    if result["status"] != "completed":
        raise RuntimeError("The provider did not complete concept extraction.")
    content = [part for item in result["output"] if item["type"] == "message" for part in item["content"]]
    if any(part["type"] == "refusal" for part in content):
        raise RuntimeError("The model declined to extract concepts.")
    text = "".join(part["text"] for part in content if part["type"] == "output_text")
    return parse_concepts(json.loads(text), catalog)


def atomic_write(path, text):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=".wiki-", delete=False) as temp:
        temporary = Path(temp.name)
        try:
            temp.write(text)
            temp.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def update_block(path, name, body, initial=""):
    text = path.read_text(encoding="utf-8") if path.exists() else initial
    start, end = f"<!-- learning-wiki:{name}:start -->", f"<!-- learning-wiki:{name}:end -->"
    if start in body or end in body:
        raise RuntimeError("Source content collides with its managed block markers.")
    if text.count(start) != text.count(end) or text.count(start) > 1:
        raise RuntimeError(f"Managed block markers were edited in {path.name}; restore them before retrying.")
    block = start + "\n" + body + ("" if body.endswith("\n") else "\n") + end if body else ""
    if start not in text:
        return text + ("\n\n" + block + "\n" if block else "")
    before, _, tail = text.partition(start)
    _, separator, after = tail.partition(end)
    if not separator:
        raise RuntimeError(f"Managed block markers are out of order in {path.name}.")
    return before + block + after


def link(title, target):
    label = title.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]")
    return f"[{label}]({target})"


def ingest(snapshot, vault, codex_home):
    for directory in ("Concepts", "Sources", "Notes", ".learning-wiki"):
        (vault / directory).mkdir(parents=True, exist_ok=True)
    with (vault / ".learning-wiki/lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state_path = vault / ".learning-wiki/state.json"
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {"sources": {}, "concepts": {}}
        previous = state["sources"].get(snapshot.id)
        digest = hashlib.sha256(snapshot.content.encode()).hexdigest()
        if previous:
            if snapshot.version < tuple(previous["version"]):
                return {"status": "stale"}
            if digest == previous["digest"]:
                if snapshot.version != tuple(previous["version"]):
                    previous["version"] = list(snapshot.version)
                    atomic_write(state_path, json.dumps(state, indent=2) + "\n")
                return {"status": "unchanged"}
            if snapshot.version == tuple(previous["version"]):
                raise RuntimeError("Different snapshot contents have the same version; retry with a fresh saved record.")

        concepts = extract(snapshot, state["concepts"], codex_home)
        current = {concept.id: concept for concept in concepts}
        state["concepts"].update({concept.id: concept.title for concept in concepts})
        state["sources"][snapshot.id] = {
            "path": snapshot.path, "note": snapshot.note, "title": snapshot.title,
            "version": list(snapshot.version), "digest": digest, "concepts": list(current),
        }
        pages = {}
        affected = current.keys() | set(previous["concepts"] if previous else [])
        for slug in sorted(affected):
            path = vault / "Concepts" / f"{slug}.md"
            body = ""
            if slug in current:
                concept = current[slug]
                body = "## From " + link(snapshot.title, "../Sources/" + snapshot.note) + "\n\n" + concept.body
                if concept.related:
                    body += "\n\nRelated: " + ", ".join(
                        link(state["concepts"][other], other + ".md") for other in concept.related)
            pages[path] = update_block(path, "source:" + snapshot.id, body, "# " + state["concepts"][slug] + "\n")

        source_links = ", ".join(link(concept.title, "../Concepts/" + concept.id + ".md") for concept in concepts)
        body = "Concepts: " + (source_links or "No reusable concepts extracted.")
        body += "\n\nOriginal record: " + link("open saved explanation", Path(snapshot.path).as_uri())
        body += "\n\n## Saved explanation\n\n" + snapshot.content
        path = vault / "Sources" / snapshot.note
        pages[path] = update_block(path, "explanation:" + snapshot.id, body, "# " + snapshot.title + "\n")

        notes = vault / "Notes/README.md"
        if not notes.exists():
            pages[notes] = "# Personal notes\n\nWrite your own notes here and link to pages in `../Concepts/`.\n"
        index = "## Concepts\n\n" + "\n".join(
            "- " + link(title, f"Concepts/{slug}.md")
            for slug, title in sorted(state["concepts"].items(), key=lambda item: item[1].casefold()))
        index += "\n\n## Source conversations\n\n" + "\n".join(
            "- " + link(source["title"], "Sources/" + source["note"])
            for source in sorted(state["sources"].values(), key=lambda item: item["note"]))
        path = vault / "Learning.md"
        pages[path] = update_block(path, "index", index,
                                  "# Learning Wiki\n\nEnglish concepts grounded in saved code explanations.\n\n"
                                  "Add your thoughts outside generated blocks, or use [personal notes](Notes/README.md).\n")

        for path, text in pages.items():
            atomic_write(path, text)
        atomic_write(state_path, json.dumps(state, indent=2) + "\n")
        return {"status": "updated", "concepts": len(concepts), "source": "Sources/" + snapshot.note}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", type=Path, default=Path("~/Documents/Obsidian Vault/04-CodeWiki"))
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", "~/.codex")))
    parser.add_argument("records", type=Path, nargs="*", help="Completed records; otherwise read one snapshot JSON from stdin")
    args = parser.parse_args()
    try:
        snapshots = (Snapshot.from_file(path) for path in args.records) if args.records else [Snapshot.from_payload(json.load(sys.stdin))]
        for snapshot in snapshots:
            result = ingest(snapshot, args.vault.expanduser().resolve(), args.codex_home.expanduser())
            print(json.dumps(result), flush=True)
    except urllib.error.HTTPError as error:
        print(f"Learning Wiki: provider HTTP {error.code}. Check API access and retry the saved record.", file=sys.stderr)
        return 1
    except (TimeoutError, urllib.error.URLError):
        print("Learning Wiki: could not reach the provider. Retry the saved record when connected.", file=sys.stderr)
        return 1
    except RuntimeError as error:
        print("Learning Wiki: " + str(error), file=sys.stderr)
        return 1
    except Exception as error:
        print("Learning Wiki: could not read the snapshot, vault, or provider configuration/response ("
              + type(error).__name__ + ").", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
