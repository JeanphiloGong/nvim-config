local M = {}

local state = {
  buf = nil,
  tabpage = nil,
  win = nil,
  selected_row = 1,
  show_all = false,
  panes = {},
  tree_rows = {},
  expanded = {},
  line_to_index = {},
  row_lines = {},
  status_cols = {},
  tree_top = 1,
  generated_at = nil,
  counts = {},
  preview_lines = {},
  preview_focus = false,
  preview_top = nil,
  preview_col = 0,
  restore = {},
  restore_mode = false,
  restore_log_keys = {},
  orchestration = nil,
  timer = nil,
  last_scan_ms = nil,
  input_active = false,
}

local ns = vim.api.nvim_create_namespace("agent_board")
local uv = vim.uv or vim.loop
local header_lines = 5
local footer_lines = 2

local function config_path(...)
  return table.concat(vim.list_extend({ vim.fn.stdpath("config") }, { ... }), "/")
end

local function scanner_path()
  return config_path("tmux", "bin", "tmux-agent-scan")
end

local function orchestrator_path()
  return config_path("tmux", "bin", "tmux-agent-orch")
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "AgentBoard" })
end

local function decode_json(text)
  if vim.json and vim.json.decode then
    return vim.json.decode(text)
  end
  return vim.fn.json_decode(text)
end

local function run_scan()
  local cmd = { scanner_path() }
  if state.show_all then
    table.insert(cmd, "--all")
  end

  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    notify("tmux-agent-scan failed", vim.log.levels.ERROR)
    return nil
  end

  local ok, data = pcall(decode_json, output)
  if not ok or type(data) ~= "table" then
    notify("Invalid tmux-agent-scan output", vim.log.levels.ERROR)
    return nil
  end

  return data
end

local function tmux_output(args)
  local cmd = { "tmux" }
  vim.list_extend(cmd, args)
  return vim.fn.system(cmd)
end

local function run_orchestrator(args)
  local cmd = { orchestrator_path() }
  vim.list_extend(cmd, args)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    notify("tmux-agent-orch failed", vim.log.levels.ERROR)
    return nil
  end
  return output
end

local function load_orchestration()
  local output = run_orchestrator({ "status", "--json" })
  if not output then
    return nil
  end
  local ok, data = pcall(decode_json, output)
  if not ok or type(data) ~= "table" then
    notify("Invalid tmux-agent-orch output", vim.log.levels.ERROR)
    return nil
  end
  return data
end

local function ensure_highlights()
  vim.api.nvim_set_hl(0, "AgentBoardHeader", { bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardDim", { fg = "#777777" })
  vim.api.nvim_set_hl(0, "AgentBoardBlocked", { fg = "#ff6b6b", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardError", { fg = "#ff4d4d", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardStale", { fg = "#f4a261", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardReviewReady", { fg = "#80ed99", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardWorking", { fg = "#ffd166", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardDone", { fg = "#4cc9f0", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardIdle", { fg = "#80ed99" })
  vim.api.nvim_set_hl(0, "AgentBoardUnknown", { fg = "#aaaaaa" })
end

local function state_hl(agent_state)
  return ({
    blocked = "AgentBoardBlocked",
    error = "AgentBoardError",
    stale = "AgentBoardStale",
    ["review-ready"] = "AgentBoardReviewReady",
    working = "AgentBoardWorking",
    done = "AgentBoardDone",
    idle = "AgentBoardIdle",
    unknown = "AgentBoardUnknown",
  })[agent_state] or "AgentBoardUnknown"
end

local function state_sign(agent_state)
  return ({
    blocked = "",
    error = "",
    stale = "󰔚",
    ["review-ready"] = "",
    working = "",
    done = "",
    idle = "",
    unknown = "",
  })[agent_state] or ""
end

local function kind_sign(kind)
  return ({
    session = "󰣇",
    window = "",
  })[kind] or "•"
end

local function agent_sign(agent)
  return ({
    codex = "",
    claude = "󰚩",
    opencode = "",
    gemini = "",
    copilot = "",
    cursor = "󰆿",
    droid = "",
    amp = "",
    pi = "π",
    kimi = "󰘦",
  })[agent] or ""
end

local function truncate(text, width)
  text = tostring(text or ""):gsub("\t", " "):gsub("\n", " ")
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local result = ""
  local chars = vim.fn.strchars(text)
  for index = 1, chars do
    local next_text = vim.fn.strcharpart(text, 0, index)
    if vim.fn.strdisplaywidth(next_text .. "...") > width then
      break
    end
    result = next_text
  end
  return result .. "..."
end

local function pane_location(pane)
  local target = string.format("%s:%s.%s", pane.session or "-", pane.window or "-", pane.pane_index or "-")
  local window_name = pane.window_name or ""
  if window_name ~= "" then
    return target .. " " .. window_name
  end
  return target
end

local function pane_target(pane)
  return string.format("%s:%s.%s", pane.session or "-", pane.window or "-", pane.pane_index or "-")
end

local status_order = { "blocked", "error", "stale", "review-ready", "working", "done", "idle", "unknown" }
local status_rank = {
  blocked = 1,
  error = 2,
  stale = 3,
  ["review-ready"] = 4,
  working = 5,
  done = 6,
  idle = 7,
  unknown = 8,
}

local function count_state(counts, agent_state)
  counts[agent_state or "unknown"] = (counts[agent_state or "unknown"] or 0) + 1
end

local function count_summary(counts)
  local parts = {}
  for _, name in ipairs(status_order) do
    local count = counts[name] or 0
    if count > 0 then
      table.insert(parts, name .. "=" .. count)
    end
  end
  return table.concat(parts, " ")
end

local function node_status(counts)
  for _, name in ipairs(status_order) do
    if (counts[name] or 0) > 0 then
      return name
    end
  end
  return "unknown"
end

local function selected_row()
  return state.tree_rows[state.selected_row]
end

local function selected_pane()
  local row = selected_row()
  if row and row.kind == "pane" then
    return row.pane
  end
  return nil
end

local function selected_workspace_title()
  local row = selected_row()
  if not row then
    return "Workspace"
  end
  if row.kind == "pane" then
    return pane_location(row.pane)
  end
  return row.title or "Workspace"
end

local function selected_session_name()
  local row = selected_row()
  if not row then
    return ""
  end
  if row.kind == "session" then
    return row.title or ""
  end
  if row.kind == "pane" and row.pane then
    return row.pane.session or ""
  end
  if type(row.panes) == "table" and row.panes[1] then
    return row.panes[1].session or ""
  end
  return ""
end

local function row_workspace_title(row)
  if not row then
    return "Workspace"
  end
  if row.kind == "pane" then
    return pane_location(row.pane)
  end
  local summary = count_summary(row.counts)
  if summary ~= "" then
    return row.title .. "  " .. summary
  end
  return row.title or "Workspace"
end

local function select_row_id(row_id)
  for index, row in ipairs(state.tree_rows) do
    if row.id == row_id then
      state.selected_row = index
      return true
    end
  end
  return false
end

local function pad(text, width)
  text = tostring(text or ""):gsub("\t", " "):gsub("\n", " ")
  local display_width = vim.fn.strdisplaywidth(text)
  if display_width >= width then
    return truncate(text, width)
  end
  return text .. string.rep(" ", width - display_width)
end

local function with_right_status(body, status, width)
  local status_width = vim.fn.strdisplaywidth(status)
  local body_width = math.max(1, width - status_width - 1)
  local padded_body = pad(body, body_width)
  local text = padded_body .. " " .. status
  return text, #padded_body + 1, #text
end

local function preview_history_lines()
  local lines = tonumber(vim.g.agent_board_preview_history_lines)
  if lines and lines > 0 then
    return math.floor(lines)
  end
  return 2000
end

local function capture_preview(pane, include_history)
  if not pane or not pane.pane_id then
    return {}
  end

  local cmd = { "capture-pane", "-p", "-J" }
  if include_history then
    vim.list_extend(cmd, { "-S", "-" .. preview_history_lines() })
  end
  vim.list_extend(cmd, { "-t", pane.pane_id })
  local output = tmux_output(cmd)
  local lines = vim.split(output or "", "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines, #lines)
  end
  return lines
end

local function pane_display_name(pane)
  if not pane then
    return "-"
  end
  return pane.label or pane_location(pane)
end

local function pane_activity(pane)
  if not pane then
    return "-"
  end
  if pane.headline and pane.headline ~= "" then
    return pane.headline
  end
  if pane.current and pane.current ~= "" then
    return pane.current
  end
  if pane.activity and pane.activity ~= "" then
    return pane.activity
  end
  if pane.summary and pane.summary ~= "" then
    return pane.summary
  end
  if pane.message and pane.message ~= "" then
    return pane.message
  end
  return pane_display_name(pane)
end

local function pane_phase(pane)
  if pane and pane.phase and pane.phase ~= "" then
    return pane.phase
  end
  return "unknown"
end

local function relative_time(epoch)
  local stamp = tonumber(epoch or "")
  if not stamp or stamp <= 0 then
    return "unknown"
  end
  local delta = math.max(0, os.time() - stamp)
  if delta < 60 then
    return tostring(delta) .. "s ago"
  end
  if delta < 3600 then
    return tostring(math.floor(delta / 60)) .. "m ago"
  end
  return tostring(math.floor(delta / 3600)) .. "h ago"
end

local function add_detail(lines, label, value)
  if value and value ~= "" then
    table.insert(lines, string.format("  %-8s %s", label .. ":", value))
    return true
  end
  return false
end

local function add_plan(lines, plan)
  if type(plan) ~= "table" or vim.tbl_isempty(plan) then
    return false
  end
  table.insert(lines, "  Plan:")
  for index, item in ipairs(plan) do
    if type(item) == "table" then
      local status = item.status or "todo"
      local text = item.text or ""
      if text ~= "" then
        table.insert(lines, string.format("    %d. %-5s %s", index, status, text))
      end
    end
  end
  return true
end

local function pane_blocked(pane)
  if pane and pane.blocked and pane.blocked ~= "" then
    return pane.blocked
  end
  if pane and pane.need and pane.need ~= "" then
    return pane.need
  end
  return ""
end

local function pane_outcome(pane)
  if pane and pane.brief_outcome and pane.brief_outcome ~= "" then
    return pane.brief_outcome
  end
  if pane and pane.outcome and pane.outcome ~= "" then
    return pane.outcome
  end
  if pane and pane.summary and pane.summary ~= "" then
    return pane.summary
  end
  return ""
end

local function restore_items()
  if type(state.restore) == "table" and type(state.restore.items) == "table" then
    return state.restore.items
  end
  return {}
end

local function restore_item_for_pane(pane)
  if not pane or not pane.pane_id then
    return nil
  end
  for _, item in ipairs(restore_items()) do
    if item.target_pane_id == pane.pane_id then
      return item
    end
  end
  return nil
end

local function restore_status_title(status)
  return ({
    ["restorable-existing-pane"] = "RESTORABLE",
    ["already-running"] = "ALREADY RUNNING",
    ["occupied-pane"] = "OCCUPIED",
    ["missing-pane"] = "MISSING PANE",
    ["missing-session-id"] = "MISSING SESSION ID",
  })[status] or "UNKNOWN"
end

local function restore_count_summary()
  local counts = type(state.restore) == "table" and state.restore.counts or {}
  local order = { "restorable-existing-pane", "already-running", "occupied-pane", "missing-pane", "missing-session-id" }
  local parts = {}
  for _, name in ipairs(order) do
    local count = tonumber(counts and counts[name]) or 0
    if count > 0 then
      table.insert(parts, name .. "=" .. count)
    end
  end
  if #parts == 0 then
    return "no saved Codex records"
  end
  return table.concat(parts, " ")
end

local function add_restore_item(lines, item)
  local target = item.target_pane_id or ""
  if target == "" then
    target = item.last_target or item.last_pane_id or "-"
  end
  local headline = item.goal or item.reason or ""
  table.insert(lines, string.format("- %-24s %s", truncate(target, 24), truncate(headline, 96)))
  add_detail(lines, "Status", item.status)
  add_detail(lines, "Reason", item.reason)
  add_detail(lines, "Session", item.codex_session_id)
  add_detail(lines, "Path", item.cwd)
end

local function restore_report_lines()
  local selected = selected_pane()
  local selected_item = restore_item_for_pane(selected)
  local lines = {
    "AGENT RESTORE",
    string.rep("-", 64),
    restore_count_summary(),
    "",
    "Actions",
    "R refresh this report",
    "Enter/Space resume the selected restorable pane",
    "J jump to selected pane",
    "",
  }

  if selected then
    add_detail(lines, "Selected", pane_location(selected))
    if selected_item then
      add_detail(lines, "Restore", selected_item.status)
      add_detail(lines, "Reason", selected_item.reason)
    else
      add_detail(lines, "Restore", "No saved Codex session matched this pane")
    end
    table.insert(lines, "")
  end

  local groups = { "restorable-existing-pane", "occupied-pane", "missing-session-id", "missing-pane", "already-running" }
  local any = false
  for _, status in ipairs(groups) do
    local group = {}
    for _, item in ipairs(restore_items()) do
      if item.status == status then
        table.insert(group, item)
      end
    end
    if #group > 0 then
      any = true
      table.insert(lines, restore_status_title(status) .. " (" .. tostring(#group) .. ")")
      for _, item in ipairs(group) do
        add_restore_item(lines, item)
      end
      table.insert(lines, "")
    end
  end

  if not any then
    table.insert(lines, "No saved Codex records found.")
  end
  return lines
end

local function sorted_scope_panes(panes)
  local sorted = vim.deepcopy(panes or {})
  table.sort(sorted, function(a, b)
    local a_rank = status_rank[a.state or "unknown"] or status_rank.unknown
    local b_rank = status_rank[b.state or "unknown"] or status_rank.unknown
    if a_rank ~= b_rank then
      return a_rank < b_rank
    end
    local a_target = string.format("%s:%s.%s", a.session or "", a.window or "", a.pane_index or "")
    local b_target = string.format("%s:%s.%s", b.session or "", b.window or "", b.pane_index or "")
    return a_target < b_target
  end)
  return sorted
end

local function add_agent_card(lines, pane)
  local status = pane.state or "unknown"
  local target = truncate(pane_location(pane), 24)
  local updated = relative_time(pane.updated)
  table.insert(
    lines,
    string.format(
      "%s %s %-8s %-12s %s",
      state_sign(status),
      agent_sign(pane.agent),
      pane.agent or "-",
      target,
      truncate(pane_activity(pane) .. "  updated=" .. updated, 80)
    )
  )
  local has_detail = false
  has_detail = add_detail(lines, "Goal", pane.goal) or has_detail
  has_detail = add_detail(lines, "Now", pane.current or pane_activity(pane)) or has_detail
  has_detail = add_detail(lines, "Evidence", pane.evidence) or has_detail
  has_detail = add_detail(lines, "Next", pane.next) or has_detail
  has_detail = add_detail(lines, "Blocked", pane_blocked(pane)) or has_detail
  has_detail = add_detail(lines, "Outcome", pane_outcome(pane)) or has_detail
  if not has_detail then
    add_detail(lines, "Now", "No current activity reported")
  end
  table.insert(lines, "")
end

local function pane_in_states(pane, names)
  for _, name in ipairs(names) do
    if pane.state == name then
      return true
    end
  end
  return false
end

local function add_scope_group(lines, title, panes, states, limit)
  local group = {}
  for _, pane in ipairs(panes) do
    if pane_in_states(pane, states) then
      table.insert(group, pane)
    end
  end
  if #group == 0 then
    return
  end

  table.insert(lines, title .. " (" .. tostring(#group) .. ")")
  for index, pane in ipairs(group) do
    if index > limit then
      table.insert(lines, string.format("... %s more", #group - limit))
      table.insert(lines, "")
      break
    end
    add_agent_card(lines, pane)
  end
end

local function count_value(counts, name)
  if type(counts) ~= "table" then
    return 0
  end
  return tonumber(counts[name]) or 0
end

local function add_orch_count_line(lines, label, counts, names)
  local parts = {}
  for _, name in ipairs(names) do
    local count = count_value(counts, name)
    if count > 0 then
      table.insert(parts, name .. "=" .. tostring(count))
    end
  end
  if #parts == 0 then
    table.insert(lines, label .. ": none")
  else
    table.insert(lines, label .. ": " .. table.concat(parts, " "))
  end
end

local function add_task_line(lines, task)
  local agent = ""
  if task.assigned_agent_id and task.assigned_agent_id ~= "" then
    agent = " -> " .. task.assigned_agent_id
  end
  local waits = ""
  if type(task.waiting_on) == "table" and #task.waiting_on > 0 then
    waits = " waits=" .. table.concat(task.waiting_on, ",")
  end
  table.insert(
    lines,
    string.format(
      "- %-4s %-8s %-8s %s%s%s",
      task.task_id or "-",
      task.status or "-",
      task.owner_role or "-",
      truncate(task.title or "", 62),
      agent,
      waits
    )
  )
  if type(task.blocker) == "table" and task.blocker.body and task.blocker.body ~= "" then
    add_detail(lines, "Blocker", string.format("%s -> %s: %s", task.blocker.from or "-", task.blocker.to or "-", task.blocker.body))
  end
  local outputs = task.outputs
  if type(outputs) == "table" and #outputs > 0 then
    local latest = outputs[#outputs]
    add_detail(lines, "Output", string.format("%s %s", latest.from or "-", latest.status or "-"))
  end
end

local function add_orch_task_group(lines, title, tasks, limit)
  if type(tasks) ~= "table" or #tasks == 0 then
    return
  end
  table.insert(lines, "")
  table.insert(lines, title .. " (" .. tostring(#tasks) .. ")")
  for index, task in ipairs(tasks) do
    if index > limit then
      table.insert(lines, string.format("... %s more", #tasks - limit))
      break
    end
    add_task_line(lines, task)
  end
end

local function orchestration_lines()
  local orch = state.orchestration
  if type(orch) ~= "table" then
    return {
      "ORCHESTRATION",
      string.rep("-", 64),
      "No orchestration state loaded.",
      "",
      "Actions",
      "O start a goal",
      "T dispatch next ready task",
      "",
    }
  end

  local board = type(orch.board) == "table" and orch.board or {}
  local meta = type(orch.meta) == "table" and orch.meta or {}
  local groups = type(board.tasks_by_status) == "table" and board.tasks_by_status or {}
  local lines = {
    "ORCHESTRATION",
    string.rep("-", 64),
    "Goal: " .. (meta.goal and meta.goal ~= "" and meta.goal or "-"),
    "Root: " .. (orch.root or "-"),
  }
  add_orch_count_line(lines, "Tasks", board.task_counts, { "ready", "running", "waiting", "blocked", "done" })
  add_orch_count_line(lines, "Agents", board.agent_counts, { "idle", "busy", "waiting", "blocked", "done" })

  add_orch_task_group(lines, "BLOCKED", groups.blocked, 4)
  add_orch_task_group(lines, "RUNNING", groups.running, 6)
  add_orch_task_group(lines, "READY", groups.ready, 6)
  add_orch_task_group(lines, "WAITING", groups.waiting, 6)
  add_orch_task_group(lines, "DONE", groups.done, 4)

  if type(orch.recent_messages) == "table" and #orch.recent_messages > 0 then
    table.insert(lines, "")
    table.insert(lines, "MESSAGES")
    local start = math.max(1, #orch.recent_messages - 3)
    for index = start, #orch.recent_messages do
      local message = orch.recent_messages[index]
      table.insert(
        lines,
        string.format(
          "- %-10s %s -> %s %s",
          message.type or "-",
          message.from or "-",
          message.to or "-",
          truncate(message.task_id or message.body or "", 54)
        )
      )
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Actions")
  table.insert(lines, "O start/reset orchestration goal")
  table.insert(lines, "T dispatch next ready task, auto-creating a worker if needed")
  table.insert(lines, "J jumps only when a pane row is selected")
  table.insert(lines, "")
  return lines
end

local function node_workspace_lines(row)
  if not row or row.kind == "pane" then
    return {}
  end
  local next_level = row.kind == "session" and "windows" or "panes"
  local panes = sorted_scope_panes(row.panes)
  local lines = {
    row_workspace_title(row),
    "",
    string.format(
      "Scope: %s    Agents: %s    Children: %s %s",
      row.kind,
      tostring(row.pane_count or 0),
      tostring(row.child_count or 0),
      next_level
    ),
    "Health: " .. (count_summary(row.counts) ~= "" and count_summary(row.counts) or "empty"),
    "",
  }

  vim.list_extend(lines, orchestration_lines())

  if #panes == 0 then
    table.insert(lines, "No agent panes in this scope.")
  else
    add_scope_group(lines, "ATTENTION", panes, { "blocked", "error", "stale" }, 6)
    add_scope_group(lines, "READY FOR REVIEW", panes, { "review-ready" }, 6)
    add_scope_group(lines, "IN PROGRESS", panes, { "working" }, 8)
    add_scope_group(lines, "COMPLETE", panes, { "done" }, 4)
    add_scope_group(lines, "QUIET", panes, { "idle", "unknown" }, 4)
  end

  table.insert(lines, "")
  table.insert(lines, "Actions")
  table.insert(lines, state.expanded[row.id] and "Enter/Space collapse this scope" or "Enter/Space expand this scope")
  table.insert(lines, "gw expand working agents")
  table.insert(lines, "gr expand review-ready agents")
  table.insert(lines, "Select a pane row for the single-agent workspace.")

  return lines
end

local function agent_workspace_lines(pane)
  local lines = {
    pane_location(pane),
    "",
    "MANAGER BRIEF",
    string.rep("-", 64),
    string.format(
      "%s %s    agent=%s    updated=%s",
      state_sign(pane.state),
      agent_sign(pane.agent),
      pane.agent or "-",
      relative_time(pane.updated)
    ),
  }
  add_detail(lines, "Target", pane_target(pane))
  add_detail(lines, "Window", pane.window_name)
  add_detail(lines, "Goal", pane.goal)
  add_plan(lines, pane.plan)
  add_detail(lines, "Current Focus", pane.current or pane_activity(pane))
  add_detail(lines, "Latest Evidence", pane.evidence)
  add_detail(lines, "Next", pane.next)
  add_detail(lines, "Blocked", pane_blocked(pane))
  add_detail(lines, "Outcome", pane_outcome(pane))
  add_detail(lines, "Path", pane.path)
  table.insert(lines, "")
  table.insert(lines, "PANE VIEW")
  table.insert(lines, string.rep("-", 64))
  vim.list_extend(lines, capture_preview(pane, false))
  return lines
end

local function compose_row(left, right, left_width, right_width)
  if right_width <= 0 then
    return left
  end
  return pad(left, left_width) .. " │ " .. truncate(right or "", right_width)
end

local function agent_board_is_current()
  return state.buf and vim.api.nvim_buf_is_valid(state.buf) and vim.api.nvim_get_current_buf() == state.buf
end

local function open_board_tab()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  vim.cmd("tabnew")
  state.tabpage = vim.api.nvim_get_current_tabpage()
  state.win = vim.api.nvim_get_current_win()
end

local function preview_refresh_interval()
  local interval = tonumber(vim.g.agent_board_preview_refresh_ms)
  if interval and interval > 0 then
    return interval
  end
  return 1000
end

local function scan_refresh_interval()
  local interval = tonumber(vim.g.agent_board_scan_refresh_ms)
  if interval and interval > 0 then
    return interval
  end
  return 5000
end

local function now_ms()
  if uv.now then
    return uv.now()
  end
  return os.time() * 1000
end

local function sorted_values(map)
  local values = {}
  for _, value in pairs(map) do
    table.insert(values, value)
  end
  table.sort(values, function(a, b)
    return tostring(a.sort_key or a.name or a.id) < tostring(b.sort_key or b.name or b.id)
  end)
  return values
end

local function build_tree_rows(panes)
  local sessions = {}
  for _, pane in ipairs(panes) do
    local session_id = pane.session_id or pane.session or "-"
    local session = sessions[session_id]
    if not session then
      session = {
        id = "session:" .. session_id,
        name = pane.session or session_id,
        sort_key = pane.session or session_id,
        counts = {},
        windows = {},
        panes = {},
        pane_count = 0,
      }
      sessions[session_id] = session
    end

    count_state(session.counts, pane.state)
    session.pane_count = session.pane_count + 1
    table.insert(session.panes, pane)

    local window_id = pane.window_id or ((pane.session or "-") .. ":" .. (pane.window or "-"))
    local window = session.windows[window_id]
    if not window then
      window = {
        id = "window:" .. window_id,
        name = string.format("%s: %s", pane.window or "-", pane.window_name or "-"),
        sort_key = tonumber(pane.window) or pane.window or window_id,
        counts = {},
        panes = {},
      }
      session.windows[window_id] = window
    end

    count_state(window.counts, pane.state)
    table.insert(window.panes, pane)
  end

  local rows = {}
  for _, session in ipairs(sorted_values(sessions)) do
    local window_count = 0
    for _ in pairs(session.windows) do
      window_count = window_count + 1
    end
    table.insert(rows, {
      kind = "session",
      id = session.id,
      title = session.name,
      depth = 0,
      counts = session.counts,
      status = node_status(session.counts),
      pane_count = session.pane_count,
      child_count = window_count,
      panes = session.panes,
    })

    if state.expanded[session.id] then
      for _, window in ipairs(sorted_values(session.windows)) do
        table.sort(window.panes, function(a, b)
          return tonumber(a.pane_index or 0) < tonumber(b.pane_index or 0)
        end)

        table.insert(rows, {
          kind = "window",
          id = window.id,
          title = window.name,
          depth = 1,
          counts = window.counts,
          status = node_status(window.counts),
          pane_count = #window.panes,
          child_count = #window.panes,
          panes = window.panes,
        })

        if state.expanded[window.id] then
          for _, pane in ipairs(window.panes) do
            table.insert(rows, {
              kind = "pane",
              id = "pane:" .. (pane.pane_id or pane_location(pane)),
              title = string.format("%s %s", pane.pane_id or "-", pane.agent or "-"),
              depth = 2,
              status = pane.state or "unknown",
              pane = pane,
            })
          end
        end
      end
    end
  end
  return rows
end

local function set_panes(data)
  local selected_id = selected_row() and selected_row().id
  state.panes = data.panes or {}
  state.counts = data.counts or {}
  state.restore = data.restore or {}
  state.generated_at = data.generated_at
  state.tree_rows = build_tree_rows(state.panes)
  if selected_id then
    select_row_id(selected_id)
  end
  if #state.tree_rows == 0 then
    state.selected_row = 1
  elseif state.selected_row > #state.tree_rows then
    state.selected_row = #state.tree_rows
  elseif state.selected_row < 1 then
    state.selected_row = 1
  end
end

local function refresh_preview(include_history)
  if state.restore_mode then
    state.preview_lines = restore_report_lines()
    state.preview_top = nil
    return
  end
  local pane = selected_pane()
  if pane then
    if include_history or state.preview_focus then
      state.preview_lines = capture_preview(pane, true)
    else
      state.preview_lines = agent_workspace_lines(pane)
    end
  else
    state.preview_lines = node_workspace_lines(selected_row())
  end
  if not state.preview_focus then
    state.preview_top = nil
  end
end

local function preview_display_height()
  return math.max(vim.api.nvim_win_get_height(0) - header_lines - footer_lines, 1)
end

local function clamp_tree_top(height)
  if #state.tree_rows == 0 then
    state.tree_top = 1
    return
  end

  local max_top = math.max(1, #state.tree_rows - height + 1)
  state.tree_top = math.max(1, math.min(max_top, state.tree_top or 1))
  if state.selected_row < state.tree_top then
    state.tree_top = state.selected_row
  elseif state.selected_row > state.tree_top + height - 1 then
    state.tree_top = state.selected_row - height + 1
  end
  state.tree_top = math.max(1, math.min(max_top, state.tree_top))
end

local function clamp_preview_top(height)
  local preview_lines = state.preview_lines or {}
  local max_top = math.max(1, #preview_lines - height + 1)
  if not state.preview_top then
    state.preview_top = max_top
  end
  state.preview_top = math.max(1, math.min(max_top, state.preview_top))
  return max_top
end

local function render_cached()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  state.line_to_index = {}
  state.row_lines = {}
  state.status_cols = {}

  local counts = state.counts or {}
  local lines = {}
  local width = vim.api.nvim_win_get_width(0)
  local left_width = math.min(math.max(28, math.floor(width * 0.28)), 40)
  local right_width = width - left_width - 3
  if right_width < 24 then
    left_width = width
    right_width = 0
  end
  local workspace_pane = selected_pane()
  local preview_lines = state.preview_lines or {}
  local preview_height = preview_display_height()
  clamp_tree_top(preview_height)
  clamp_preview_top(preview_height)
  if not state.preview_focus then
    state.preview_top = 1
  end
  local preview_slice = {}
  for index = state.preview_top, math.min(#preview_lines, state.preview_top + preview_height - 1) do
    table.insert(preview_slice, preview_lines[index])
  end
  local row = selected_row()
  local preview_header = workspace_pane and "AGENT INSPECTOR" or "SCOPE INSPECTOR"
  if state.restore_mode then
    preview_header = "RESTORE REPORT"
  end
  if state.preview_focus and #preview_lines > 0 then
    preview_header = string.format(
      "PANE HISTORY %s-%s/%s",
      state.preview_top,
      math.min(#preview_lines, state.preview_top + preview_height - 1),
      #preview_lines
    )
  end
  state.preview_col = right_width > 0 and left_width + 3 or 0

  table.insert(lines, compose_row("Agents", selected_workspace_title(), left_width, right_width))
  table.insert(
    lines,
    compose_row(
      string.format(
        "%s  scope=%s",
        count_summary(counts) ~= "" and count_summary(counts) or "empty",
        state.show_all and "all panes" or "agents"
      ),
      workspace_pane and (workspace_pane.path or "") or (row and ("Inspecting " .. row.kind .. " scope") or "Select a scope"),
      left_width,
      right_width
    )
  )
  table.insert(lines, compose_row("", "", left_width, right_width))
  table.insert(lines, compose_row("WORKSPACE", preview_header, left_width, right_width))
  table.insert(lines, compose_row(string.rep("-", left_width), string.rep("-", math.max(right_width, 0)), left_width, right_width))

  for offset = 1, preview_height do
    local index = state.tree_top + offset - 1
    local row = state.tree_rows[index]
    local left = ""
    local status_col_start = nil
    local status_col_end = nil
    if row then
      local prefix = string.rep("  ", row.depth or 0)
      local icon = " "
      if row.kind ~= "pane" then
        icon = state.expanded[row.id] and "▾" or "▸"
      end
      if row.kind == "pane" then
        local pane = row.pane
        local source = pane.source == "report" and "*" or " "
        local name = pane.label or pane_location(pane)
        local status = state_sign(pane.state)
        local body = string.format(
          "%s%s%s %s",
          prefix,
          agent_sign(pane.agent),
          source,
          truncate(name, math.max(8, left_width - 8 - #prefix))
        )
        left, status_col_start, status_col_end = with_right_status(body, status, left_width)
      else
        local status = state_sign(row.status)
        local body = string.format(
          "%s%s%s %s",
          prefix,
          icon,
          kind_sign(row.kind),
          truncate(row.title, math.max(8, left_width - 7 - #prefix))
        )
        left, status_col_start, status_col_end = with_right_status(body, status, left_width)
      end
    end
    local right = preview_slice[offset] or ""
    table.insert(lines, compose_row(left, right, left_width, right_width))
    if row then
      state.line_to_index[#lines] = index
      state.row_lines[index] = #lines
      state.status_cols[index] = { status_col_start, status_col_end }
    end
  end

  if #state.tree_rows == 0 then
    lines[header_lines + 1] = compose_row(
      "No agent panes detected. Press a to include all tmux panes.",
      preview_slice[1] or "",
      left_width,
      right_width
    )
  end

  if state.preview_focus then
    table.insert(lines, "Preview: j/k/Up/Down scroll  C-u/C-d page  Esc/q list  i send  J jump  r rescan")
  elseif state.restore_mode then
    table.insert(lines, "Restore: Enter/Space resume selected  R refresh report  J jump  r rescan  q quit")
  else
    table.insert(lines, "Keys: j/k move  O start  T tick  Enter/Space expand/preview  R restore  gw/gr/gd expand  i send  J jump  r rescan  a all  q quit")
  end
  table.insert(lines, "* means state came from an agent report hook.")

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardHeader", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardDim", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardHeader", 3, 0, -1)

  for index, row in ipairs(state.tree_rows) do
    local line = state.row_lines[index]
    local cols = state.status_cols[index]
    if line and cols then
      vim.api.nvim_buf_add_highlight(state.buf, ns, state_hl(row.status), line - 1, cols[1], cols[2])
    end
  end

  local selected_line = state.row_lines[state.selected_row]
  if selected_line and vim.api.nvim_get_current_buf() == state.buf then
    local column = state.preview_focus and state.preview_col or 0
    pcall(vim.api.nvim_win_set_cursor, 0, { selected_line, column })
  end
end

local function expand_status(target_status)
  local first_pane_id = nil

  for _, pane in ipairs(state.panes) do
    if pane.state == target_status then
      first_pane_id = first_pane_id or pane.pane_id
      if pane.session_id then
        state.expanded["session:" .. pane.session_id] = true
      else
        state.expanded["session:" .. (pane.session or "-")] = true
      end
      local window_id = pane.window_id or ((pane.session or "-") .. ":" .. (pane.window or "-"))
      state.expanded["window:" .. window_id] = true
    end
  end

  state.tree_rows = build_tree_rows(state.panes)
  if first_pane_id then
    select_row_id("pane:" .. first_pane_id)
  end
  state.preview_focus = false
  refresh_preview()
  render_cached()

  if not first_pane_id then
    notify("No " .. target_status .. " panes")
  end
end

local function render()
  local data = run_scan()
  if not data then
    return
  end
  set_panes(data)
  state.orchestration = load_orchestration()
  state.last_scan_ms = now_ms()
  refresh_preview(state.preview_focus)
  render_cached()
end

function M.refresh()
  render()
end

function M.refresh_preview()
  if state.input_active or state.preview_focus or not agent_board_is_current() then
    return
  end
  if not state.last_scan_ms or now_ms() - state.last_scan_ms >= scan_refresh_interval() then
    local data = run_scan()
    if data then
      set_panes(data)
      state.orchestration = load_orchestration()
      state.last_scan_ms = now_ms()
    end
  end
  refresh_preview()
  render_cached()
end

function M.move(delta)
  if #state.tree_rows == 0 then
    return
  end
  state.preview_focus = false
  state.selected_row = math.max(1, math.min(#state.tree_rows, state.selected_row + delta))
  refresh_preview()
  render_cached()
  local line = state.row_lines[state.selected_row]
  if line then
    pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  end
end

local function select_line(line)
  local index = state.line_to_index[line]
  if not index then
    return false
  end
  state.preview_focus = false
  state.selected_row = index
  refresh_preview()
  render_cached()
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  return true
end

function M.select_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  select_line(cursor[1])
end

local function tmux(args)
  tmux_output(args)
end

local function restore_log_path()
  local state_home = vim.env.XDG_STATE_HOME
  if not state_home or state_home == "" then
    state_home = (vim.env.HOME or "~") .. "/.local/state"
  end
  return state_home .. "/agent-board/restore/restore-log.jsonl"
end

local function append_restore_log(item, action, detail)
  if type(item) ~= "table" then
    return
  end
  local path = restore_log_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local record = {
    ts = os.time(),
    action = action,
    detail = detail or "",
    restore_id = item.restore_id or "",
    status = item.status or "",
    reason = item.reason or "",
    last_target = item.last_target or "",
    target_pane_id = item.target_pane_id or "",
    codex_session_id = item.codex_session_id or "",
    cwd = item.cwd or "",
  }
  vim.fn.writefile({ vim.fn.json_encode(record) }, path, "a")
end

local function log_unrestorable_items()
  for _, item in ipairs(restore_items()) do
    if item.status ~= "restorable-existing-pane" and item.status ~= "already-running" then
      local key = table.concat({ item.restore_id or "", item.status or "", tostring(item.updated or "") }, "|")
      if not state.restore_log_keys[key] then
        state.restore_log_keys[key] = true
        append_restore_log(item, "restore-unavailable", item.reason)
      end
    end
  end
end

local function restore_command(item)
  return "codex resume " .. vim.fn.shellescape(item.codex_session_id or "")
end

function M.open_restore_report()
  local data = run_scan()
  if not data then
    return
  end
  set_panes(data)
  state.restore_mode = true
  state.preview_focus = false
  log_unrestorable_items()
  refresh_preview()
  render_cached()
end

function M.resume_selected_restore()
  local pane = selected_pane()
  if not pane then
    notify("Select an existing pane first", vim.log.levels.WARN)
    return
  end

  local item = restore_item_for_pane(pane)
  if not item then
    notify("No restore record matched " .. pane_location(pane), vim.log.levels.WARN)
    return
  end
  if item.status ~= "restorable-existing-pane" or not item.restorable then
    append_restore_log(item, "resume-blocked", item.reason)
    notify("Cannot resume: " .. (item.reason or item.status), vim.log.levels.WARN)
    return
  end
  if not item.codex_session_id or item.codex_session_id == "" then
    append_restore_log(item, "resume-blocked", "missing codex_session_id")
    notify("Cannot resume: missing codex_session_id", vim.log.levels.WARN)
    return
  end

  local cmd = restore_command(item)
  if pane.pane_dead then
    tmux({ "respawn-pane", "-k", "-t", pane.pane_id, cmd })
  else
    tmux({ "send-keys", "-t", pane.pane_id, "-l", cmd })
    tmux({ "send-keys", "-t", pane.pane_id, "Enter" })
  end
  append_restore_log(item, "resume-sent", cmd)
  notify("Sent codex resume to " .. pane_location(pane))
  vim.defer_fn(function()
    if agent_board_is_current() then
      M.refresh()
    end
  end, 500)
end

function M.toggle_node()
  local row = selected_row()
  if not row then
    return
  end
  if state.restore_mode and row.kind == "pane" then
    M.resume_selected_restore()
    return
  end
  if row.kind == "pane" then
    M.enter_preview()
    return
  end

  state.expanded[row.id] = not state.expanded[row.id]
  state.tree_rows = build_tree_rows(state.panes)
  select_row_id(row.id)
  state.preview_focus = false
  render_cached()
end

function M.jump()
  local pane = selected_pane()
  if not pane then
    return
  end

  tmux({ "switch-client", "-t", pane.session })
  tmux({ "select-window", "-t", pane.session .. ":" .. pane.window })
  tmux({ "select-pane", "-t", pane.pane_id })

  if vim.env.TMUX_AGENT_BOARD_QUIT_ON_JUMP == "1" then
    M.stop_timer()
    vim.schedule(function()
      vim.cmd("qa!")
    end)
  else
    notify("Jumped to " .. pane_location(pane))
  end
end

function M.send_to_selected()
  local pane = selected_pane()
  if not pane then
    notify("Select a pane row first", vim.log.levels.WARN)
    return
  end

  state.input_active = true
  vim.ui.input({ prompt = "Send to " .. pane_location(pane) .. ": " }, function(input)
    state.input_active = false
    if not input or input == "" then
      return
    end
    tmux({ "send-keys", "-t", pane.pane_id, "-l", input })
    tmux({ "send-keys", "-t", pane.pane_id, "Enter" })
    vim.schedule(function()
      if agent_board_is_current() then
        refresh_preview(state.preview_focus)
        render_cached()
      end
    end)
  end)
end

function M.start_orchestration()
  state.input_active = true
  vim.ui.input({ prompt = "Orchestration goal: " }, function(input)
    state.input_active = false
    if not input or input == "" then
      return
    end
    local args = { "start", "--goal", input, "--example", "mini-kanban", "--workdir", vim.fn.getcwd() }
    local session = selected_session_name()
    if session ~= "" then
      vim.list_extend(args, { "--session", session })
    end
    local output = run_orchestrator(args)
    if not output then
      return
    end
    notify(vim.trim(output))
    state.orchestration = load_orchestration()
    refresh_preview(false)
    render_cached()
  end)
end

function M.tick_orchestration()
  local args = { "tick", "--auto-create", "--workdir", vim.fn.getcwd() }
  local session = selected_session_name()
  if session ~= "" then
    vim.list_extend(args, { "--session", session })
  end
  local output = run_orchestrator(args)
  if not output then
    return
  end
  notify(vim.trim(output))
  state.orchestration = load_orchestration()
  refresh_preview(false)
  render_cached()
end

function M.enter_preview()
  if not selected_pane() then
    return
  end
  if #state.preview_lines == 0 then
    return
  end
  state.preview_top = nil
  state.preview_focus = true
  refresh_preview(true)
  state.preview_top = math.max(1, #state.preview_lines - preview_display_height() + 1)
  render_cached()
end

function M.leave_preview()
  if state.restore_mode then
    state.restore_mode = false
    state.preview_top = nil
    refresh_preview()
    render_cached()
    return
  end
  if not state.preview_focus then
    return
  end
  state.preview_focus = false
  state.preview_top = nil
  refresh_preview()
  render_cached()
end

function M.close_or_leave_preview()
  if state.preview_focus then
    M.leave_preview()
    return
  end
  M.close()
end

function M.scroll_preview(delta)
  if not state.preview_focus then
    M.move(delta)
    return
  end
  local height = preview_display_height()
  local max_top = math.max(1, #(state.preview_lines or {}) - height + 1)
  state.preview_top = math.max(1, math.min(max_top, (state.preview_top or max_top) + delta))
  render_cached()
end

function M.scroll_preview_page(delta)
  local height = preview_display_height()
  M.scroll_preview(delta * math.max(1, height - 1))
end

function M.toggle_all()
  state.show_all = not state.show_all
  state.preview_focus = false
  state.selected_row = 1
  render()
end

function M.expand_working()
  expand_status("working")
end

function M.expand_review_ready()
  expand_status("review-ready")
end

function M.expand_done()
  expand_status("done")
end

function M.close()
  M.stop_timer()
  if vim.env.TMUX_AGENT_BOARD_QUIT_ON_JUMP == "1" or vim.env.TMUX_AGENT_BOARD_QUIT_ON_CLOSE == "1" then
    vim.cmd("qa!")
    return
  end

  local tabpage = state.tabpage
  local closes_dedicated_tab = tabpage
    and vim.api.nvim_tabpage_is_valid(tabpage)
    and #vim.api.nvim_list_tabpages() > 1
    and #vim.api.nvim_tabpage_list_wins(tabpage) == 1

  if closes_dedicated_tab then
    vim.api.nvim_set_current_tabpage(tabpage)
    vim.cmd("tabclose!")
    state.win = nil
    state.tabpage = nil
    return
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.cmd("bdelete!")
  end
  state.win = nil
  state.tabpage = nil
end

function M.start_timer()
  if state.timer then
    return
  end
  local timer = uv.new_timer()
  local interval = preview_refresh_interval()
  state.timer = timer
  timer:start(interval, interval, vim.schedule_wrap(function()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
      M.stop_timer()
      return
    end
    M.refresh_preview()
  end))
end

function M.stop_timer()
  local timer = state.timer
  state.timer = nil
  if timer then
    timer:stop()
    timer:close()
  end
end

local function map(buf, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
end

local function attach_maps(buf)
  map(buf, "q", M.close_or_leave_preview, "Close AgentBoard or leave preview")
  map(buf, "r", M.refresh, "Refresh AgentBoard")
  map(buf, "R", M.open_restore_report, "Open restore report")
  map(buf, "O", M.start_orchestration, "Start orchestration goal")
  map(buf, "T", M.tick_orchestration, "Dispatch next orchestration task")
  map(buf, "a", M.toggle_all, "Toggle all tmux panes")
  map(buf, "gw", M.expand_working, "Expand working agents")
  map(buf, "gr", M.expand_review_ready, "Expand review-ready agents")
  map(buf, "gd", M.expand_done, "Expand done agents")
  map(buf, "i", M.send_to_selected, "Send text to selected pane")
  map(buf, "j", function()
    M.scroll_preview(1)
  end, "Next agent or scroll preview")
  map(buf, "k", function()
    M.scroll_preview(-1)
  end, "Previous agent or scroll preview")
  map(buf, "<Down>", function()
    M.scroll_preview(1)
  end, "Next agent or scroll preview")
  map(buf, "<Up>", function()
    M.scroll_preview(-1)
  end, "Previous agent or scroll preview")
  map(buf, "<C-d>", function()
    M.scroll_preview_page(1)
  end, "Scroll preview down")
  map(buf, "<C-u>", function()
    M.scroll_preview_page(-1)
  end, "Scroll preview up")
  map(buf, "<C-j>", function()
    M.move(1)
  end, "Next agent")
  map(buf, "<C-l>", function()
    M.move(1)
  end, "Next agent")
  map(buf, "<C-k>", function()
    M.move(-1)
  end, "Previous agent")
  map(buf, "<C-h>", function()
    M.move(-1)
  end, "Previous agent")
  map(buf, "<Esc>", M.leave_preview, "Leave preview")
  map(buf, "<CR>", M.toggle_node, "Expand node or enter preview")
  map(buf, "<Space>", M.toggle_node, "Expand node or enter preview")
  map(buf, "J", M.jump, "Jump to pane")
  map(buf, "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == vim.api.nvim_get_current_win() then
      select_line(pos.line)
    end
  end, "Select agent")
  map(buf, "<2-LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == vim.api.nvim_get_current_win() and select_line(pos.line) then
      local row = selected_row()
      if row and row.kind == "pane" then
        M.jump()
      else
        M.toggle_node()
      end
    end
  end, "Jump to pane")
end

function M.open()
  ensure_highlights()
  vim.opt.mouse = "a"
  open_board_tab()

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "agent-board"
    vim.api.nvim_buf_set_name(state.buf, "AgentBoard")
    attach_maps(state.buf)
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = state.buf,
      once = true,
      callback = function()
        M.stop_timer()
        state.buf = nil
        state.win = nil
        state.tabpage = nil
      end,
    })
  end

  vim.api.nvim_set_current_buf(state.buf)
  state.win = vim.api.nvim_get_current_win()
  state.tabpage = vim.api.nvim_get_current_tabpage()
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = true
  render()
  M.start_timer()
end

function M.setup()
  vim.api.nvim_create_user_command("AgentBoard", function()
    M.open()
  end, { desc = "Open tmux agent board" })
end

return M
