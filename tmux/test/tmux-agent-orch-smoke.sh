#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
orch="$repo_root/tmux/bin/tmux-agent-orch"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-agent-orch.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

export AGENT_ORCH_ROOT="$tmp_root/state"
export AGENT_ORCH_DRY_RUN=1
unset TMUX

"$orch" init --goal "smoke test orchestration"
test -f "$AGENT_ORCH_ROOT/meta.json"
test -f "$AGENT_ORCH_ROOT/agents.json"
test -f "$AGENT_ORCH_ROOT/tasks.json"
test -f "$AGENT_ORCH_ROOT/messages.jsonl"
test -f "$AGENT_ORCH_ROOT/runs.json"
jq -e '.goal == "smoke test orchestration"' "$AGENT_ORCH_ROOT/meta.json" >/dev/null

"$orch" register-agent --agent-id builder-1 --role builder --pane %999
"$orch" register-agent --agent-id reviewer-1 --role reviewer --pane %999
jq -e 'length == 2 and (.[] | select(.agent_id == "reviewer-1" and .pane_id == "%999"))' "$AGENT_ORCH_ROOT/agents.json" >/dev/null

"$orch" send-message --from reviewer-1 --to builder-1 --type request --task-id T0 --body "Please include smoke evidence"
jq -e 'select(.type == "request" and .from == "reviewer-1" and .to == "builder-1" and .task_id == "T0")' "$AGENT_ORCH_ROOT/messages.jsonl" >/dev/null

"$orch" add-task --task-id T0 --title "Initialize project" --owner-role builder
"$orch" add-task --task-id T1 --title "Build UI" --depends-on T0 --owner-role builder

"$orch" tick --dry-run
jq -e '.[] | select(.task_id == "T0" and .status == "running" and .assigned_agent_id == "builder-1")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null
jq -e '.[] | select(.agent_id == "builder-1" and .state == "busy" and .current_task_id == "T0")' "$AGENT_ORCH_ROOT/agents.json" >/dev/null

"$orch" handoff --task-id T0 --from builder-1 --status done --output-json '{"changed_files":["README.md"],"checks":["smoke"],"risks":[]}'
jq -e '.[] | select(.task_id == "T0" and .status == "done")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

"$orch" tick --dry-run
jq -e '.[] | select(.task_id == "T1" and .status == "running" and .assigned_agent_id == "builder-1")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

"$orch" blocker --task-id T1 --from builder-1 --request-type missing_requirement --body "Need scope confirmation"
jq -e '.[] | select(.task_id == "T1" and .status == "blocked" and .blocker.request_type == "missing_requirement")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null
jq -e 'select(.type == "blocker" and .request_type == "missing_requirement")' "$AGENT_ORCH_ROOT/messages.jsonl" >/dev/null

"$orch" load-example mini-kanban
jq -e 'length == 6 and (.[] | select(.task_id == "T5" and .depends_on[0] == "T4"))' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

status_json="$("$orch" status --json)"
printf '%s\n' "$status_json" | jq -e '.root == env.AGENT_ORCH_ROOT and .message_count >= 1 and .board.task_counts.ready == 1 and .board.task_counts.waiting == 5' >/dev/null

export AGENT_ORCH_ROOT="$tmp_root/auto-state"
"$orch" start --goal "auto-create orchestration" --example mini-kanban --workdir "$repo_root"
jq -e '.goal == "auto-create orchestration" and .worker_window_name == "agents"' "$AGENT_ORCH_ROOT/meta.json" >/dev/null
jq -e 'length == 6' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

"$orch" ensure-agent --role builder --dry-run --workdir "$repo_root"
jq -e '.[] | select(.agent_id == "builder-1" and .role == "builder" and .pane_id == "%dry-builder-1")' "$AGENT_ORCH_ROOT/agents.json" >/dev/null

tick_output="$("$orch" tick --auto-create --dry-run --workdir "$repo_root")"
printf '%s\n' "$tick_output" | grep -F 'pane=%dry-builder-1' >/dev/null
jq -e '.[] | select(.task_id == "T0" and .status == "running" and .assigned_agent_id == "builder-1")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

"$orch" handoff --task-id T0 --from builder-1 --status done --output-json '{"changed_files":[],"checks":["dry-run"],"risks":[]}'
"$orch" tick --auto-create --dry-run --workdir "$repo_root"
jq -e '.[] | select(.task_id == "T1" and .status == "running" and .assigned_agent_id == "builder-1")' "$AGENT_ORCH_ROOT/tasks.json" >/dev/null

status_json="$("$orch" status --json)"
printf '%s\n' "$status_json" | jq -e '.board.running[0].assigned_agent.agent_id == "builder-1" and .board.agent_counts.busy == 1' >/dev/null
printf 'tmux-agent-orch smoke: OK\n'
