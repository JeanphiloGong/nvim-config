#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
apiarydeck="$repo_root/tmux/bin/apiarydeck"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/apiarydeck.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

skill_file="$tmp_root/skills/demo/SKILL.md"
mkdir -p "$(dirname "$skill_file")"
cat >"$skill_file" <<'EOF'
---
name: demo
description: demo skill
---

Use this demo skill.
EOF

"$apiarydeck" --root "$tmp_root/state" sdk-run \
  --agent-id crown-1 \
  --role crown \
  --task-id T1 \
  --task "Plan the next implementation slice." \
  --workdir "$repo_root" \
  --skill "demo:$skill_file" \
  --dry-run >/dev/null

test -f "$tmp_root/state/meta.json"
test -f "$tmp_root/state/agents.json"
test -f "$tmp_root/state/events.jsonl"

jq -e '.product == "ApiaryDeck"' "$tmp_root/state/meta.json" >/dev/null
jq -e '.[] | select(.agent_id == "crown-1" and .connector == "codex-sdk" and .thread_id == "dry-thread-crown-1" and .skills[0].name == "demo")' "$tmp_root/state/agents.json" >/dev/null
jq -e 'select(.type == "sdk_turn" and .agent_id == "crown-1" and .input[1].type == "skill" and .input[1].name == "demo")' "$tmp_root/state/events.jsonl" >/dev/null

status_json="$("$apiarydeck" --root "$tmp_root/state" status)"
printf '%s\n' "$status_json" | jq -e '.agents[0].agent_id == "crown-1" and .events[0].turn_id == "dry-turn-T1"' >/dev/null

"$apiarydeck" --root "$tmp_root/orch-state" orchestrate \
  --goal "Ship a tiny SDK orchestration MVP." \
  --workdir "$repo_root" \
  --skill "demo:$skill_file" \
  --dry-run >/dev/null

test -f "$tmp_root/orch-state/tasks.json"
jq -e '.[] | select(.agent_id == "crown-1" and .role == "crown" and .connector == "codex-sdk" and .current_goal == "Ship a tiny SDK orchestration MVP.")' "$tmp_root/orch-state/agents.json" >/dev/null
jq -e '.[] | select(.task_id == "T1" and .owner_role == "crown" and .status == "done")' "$tmp_root/orch-state/tasks.json" >/dev/null
jq -e '.[] | select(.task_id == "T2" and .owner_role == "builder" and .depends_on[0] == "T1" and .status == "ready")' "$tmp_root/orch-state/tasks.json" >/dev/null
jq -e 'select(.type == "orchestration_plan" and .role == "crown" and .goal == "Ship a tiny SDK orchestration MVP." and (.input[0].text | contains("Role: crown")) and .input[1].type == "skill")' "$tmp_root/orch-state/events.jsonl" >/dev/null

orch_status_json="$("$apiarydeck" --root "$tmp_root/orch-state" status)"
printf '%s\n' "$orch_status_json" | jq -e '.tasks | length == 2' >/dev/null

printf 'apiarydeck smoke: OK\n'
