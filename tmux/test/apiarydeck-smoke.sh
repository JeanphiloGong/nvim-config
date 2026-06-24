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

"$apiarydeck" --root "$tmp_root/orch-state" dispatch \
  --task-id T2 \
  --connector codex-sdk \
  --skill "demo:$skill_file" \
  --dry-run >/dev/null

jq -e '.[] | select(.task_id == "T2" and .status == "running" and .assigned_agent_id == "builder-1" and .connector == "codex-sdk")' "$tmp_root/orch-state/tasks.json" >/dev/null
jq -e '.[] | select(.agent_id == "builder-1" and .role == "builder" and .state == "busy" and .current_task_id == "T2")' "$tmp_root/orch-state/agents.json" >/dev/null
jq -e 'select(.type == "dispatch" and .task_id == "T2" and .agent_id == "builder-1" and (.prompt | contains("Task id: T2")))' "$tmp_root/orch-state/events.jsonl" >/dev/null

"$apiarydeck" --root "$tmp_root/orch-state" handoff \
  --task-id T2 \
  --from builder-1 \
  --status done \
  --output-json '{"checks":["apiarydeck smoke"],"risks":[]}' >/dev/null

jq -e '.[] | select(.task_id == "T2" and .status == "done" and .handoff.output.checks[0] == "apiarydeck smoke")' "$tmp_root/orch-state/tasks.json" >/dev/null
jq -e '.[] | select(.agent_id == "builder-1" and .state == "idle" and .current_task_id == "")' "$tmp_root/orch-state/agents.json" >/dev/null
jq -e 'select(.type == "handoff" and .task_id == "T2" and .status == "done")' "$tmp_root/orch-state/events.jsonl" >/dev/null

"$apiarydeck" --root "$tmp_root/blocker-state" orchestrate \
  --goal "Surface blocker flow." \
  --dry-run >/dev/null
"$apiarydeck" --root "$tmp_root/blocker-state" blocker \
  --task-id T2 \
  --from builder-1 \
  --request-type review_finding \
  --body "Need review decision." >/dev/null
jq -e '.[] | select(.task_id == "T2" and .status == "blocked" and .blocker.request_type == "review_finding")' "$tmp_root/blocker-state/tasks.json" >/dev/null

"$apiarydeck" --root "$tmp_root/loop-state" orchestrate \
  --goal "Run one loop." \
  --dry-run >/dev/null
"$apiarydeck" --root "$tmp_root/loop-state" loop --once --dry-run >/dev/null
jq -e '.[] | select(.task_id == "T2" and .status == "running" and .assigned_agent_id == "builder-1")' "$tmp_root/loop-state/tasks.json" >/dev/null

dashboard_path="$tmp_root/orch-state/dashboard.html"
"$apiarydeck" --root "$tmp_root/orch-state" dashboard --output "$dashboard_path" >/dev/null
test -f "$dashboard_path"
grep -F '<h1>ApiaryDeck</h1>' "$dashboard_path" >/dev/null
grep -F 'builder-1' "$dashboard_path" >/dev/null

printf 'apiarydeck smoke: OK\n'
