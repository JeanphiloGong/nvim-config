"""Stream code explanations using the API-key provider already configured for Codex."""

import argparse
import json
import os
from pathlib import Path
import sys
import tomllib
import urllib.error
import urllib.request


def emit(event):
    print(json.dumps(event), flush=True)


def provider_settings(home):
    config = tomllib.loads((home / "config.toml").read_text())
    provider = config.get("model_providers", {}).get(config.get("model_provider", "openai"), {})
    if provider.get("wire_api", "responses") != "responses":
        raise RuntimeError("Code explanations require a Responses API provider.")
    base = provider.get("base_url", "https://api.openai.com/v1").rstrip("/")
    key = os.environ.get(provider.get("env_key", "OPENAI_API_KEY"))
    if not key:
        key = json.loads((home / "auth.json").read_text()).get("OPENAI_API_KEY")
    if not key:
        raise RuntimeError("An API key is required in the Codex provider environment or auth.json.")
    return base, key


def sse_events(response):
    data = []
    for raw in response:
        line = raw.decode("utf-8").rstrip("\r\n")
        if line.startswith("data:"):
            data.append(line[5:].removeprefix(" "))
        elif not line and data:
            payload = "\n".join(data)
            data = []
            if payload != "[DONE]":
                yield json.loads(payload)


def complete(base, key, request):
    payload = {
        "model": request["model"],
        "instructions": request["instructions"],
        "input": [{"role": "user", "content": request["input"]}],
        "stream": True,
        "store": False,
        "service_tier": "fast",
    }
    if request["effort"] != "default":
        payload["reasoning"] = {"effort": request["effort"]}
    http = urllib.request.Request(
        base + "/responses",
        data=json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
    )
    has_text = False
    with urllib.request.urlopen(http, timeout=45) as response:
        for event in sse_events(response):
            kind = event["type"]
            if kind == "response.output_text.delta":
                text = event["delta"]
                if text:
                    has_text = True
                    emit({"type": "delta", "text": text})
            elif kind == "response.completed":
                if not has_text:
                    raise RuntimeError("The model returned no explanation.")
                emit({"type": "done"})
                return
            elif kind in ("error", "response.failed", "response.incomplete"):
                raise RuntimeError("The provider did not complete the explanation (" + kind + ").")
            elif kind == "response.refusal.delta":
                raise RuntimeError("The model declined to explain this selection.")
    raise RuntimeError("The response stream ended before completion.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser())
    parser.add_argument("action", choices=("complete", "models"))
    args = parser.parse_args()
    try:
        base, key = provider_settings(args.codex_home)
        if args.action == "models":
            http = urllib.request.Request(base + "/models", headers={"Authorization": "Bearer " + key})
            with urllib.request.urlopen(http, timeout=15) as response:
                emit({"models": [model["id"] for model in json.load(response)["data"]]})
        else:
            complete(base, key, json.load(sys.stdin))
    except urllib.error.HTTPError as error:
        emit({"type": "error", "message": f"Provider HTTP {error.code}. Check the selected model and API-key configuration."})
        return 1
    except (TimeoutError, urllib.error.URLError):
        emit({"type": "error", "message": "Could not reach the model provider. Check the connection and retry."})
        return 1
    except RuntimeError as error:
        emit({"type": "error", "message": str(error)})
        return 1
    except FileNotFoundError:
        emit({"type": "error", "message": "Codex provider configuration or API-key authentication file is missing."})
        return 1
    except Exception as error:
        emit({"type": "error", "message": "Invalid explanation request or provider response (" + type(error).__name__ + ")."})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
