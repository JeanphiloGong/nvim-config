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
  timer = nil,
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

local function ensure_highlights()
  vim.api.nvim_set_hl(0, "AgentBoardHeader", { bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardDim", { fg = "#777777" })
  vim.api.nvim_set_hl(0, "AgentBoardBlocked", { fg = "#ff6b6b", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardWorking", { fg = "#ffd166", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardDone", { fg = "#4cc9f0", bold = true })
  vim.api.nvim_set_hl(0, "AgentBoardIdle", { fg = "#80ed99" })
  vim.api.nvim_set_hl(0, "AgentBoardUnknown", { fg = "#aaaaaa" })
end

local function state_hl(agent_state)
  return ({
    blocked = "AgentBoardBlocked",
    working = "AgentBoardWorking",
    done = "AgentBoardDone",
    idle = "AgentBoardIdle",
    unknown = "AgentBoardUnknown",
  })[agent_state] or "AgentBoardUnknown"
end

local function state_sign(agent_state)
  return ({
    blocked = "",
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
    pane = "",
  })[kind] or "•"
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

local status_order = { "blocked", "working", "done", "idle", "unknown" }

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

local function node_workspace_lines(row)
  if not row or row.kind == "pane" then
    return {}
  end
  local next_level = row.kind == "session" and "windows" or "panes"
  return {
    row_workspace_title(row),
    "",
    "Type: " .. row.kind,
    "Status: " .. (count_summary(row.counts) ~= "" and count_summary(row.counts) or "empty"),
    "Panes: " .. tostring(row.pane_count or 0),
    "Children: " .. tostring(row.child_count or 0) .. " " .. next_level,
    "",
    (state.expanded[row.id] and "Enter/Space collapses this node." or "Enter/Space expands this node."),
    "Select a pane to open its agent workspace.",
  }
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
        pane_count = 0,
      }
      sessions[session_id] = session
    end

    count_state(session.counts, pane.state)
    session.pane_count = session.pane_count + 1

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
  local pane = selected_pane()
  if pane then
    state.preview_lines = capture_preview(pane, include_history or state.preview_focus)
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
  local preview_max_top = clamp_preview_top(preview_height)
  if not state.preview_focus then
    state.preview_top = preview_max_top
  end
  local preview_slice = {}
  for index = state.preview_top, math.min(#preview_lines, state.preview_top + preview_height - 1) do
    table.insert(preview_slice, preview_lines[index])
  end
  local preview_header = "PANE CONTENT"
  if state.preview_focus and #preview_lines > 0 then
    preview_header = string.format(
      "PANE CONTENT %s-%s/%s",
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
        "blocked=%s working=%s done=%s idle=%s unknown=%s  scope=%s",
        counts.blocked or 0,
        counts.working or 0,
        counts.done or 0,
        counts.idle or 0,
        counts.unknown or 0,
        state.show_all and "all panes" or "agents"
      ),
      workspace_pane and (workspace_pane.path or "") or "Select a pane to open its workspace",
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
        local left_prefix = string.format("%s%s%s%s ", source, prefix, icon, kind_sign(row.kind))
        status_col_start = #left_prefix
        status_col_end = status_col_start + #status
        left = left_prefix .. status .. " " .. truncate(name, math.max(8, left_width - 8 - #prefix))
      else
        local status = state_sign(row.status)
        local left_prefix = string.format("%s%s%s ", prefix, icon, kind_sign(row.kind))
        status_col_start = #left_prefix
        status_col_end = status_col_start + #status
        left = left_prefix .. status .. " " .. truncate(row.title, math.max(8, left_width - 7 - #prefix))
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
  else
    table.insert(lines, "Keys: j/k move  Enter/Space expand/preview  gw working  gd done  i send  J jump  r rescan  a all  q quit")
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

function M.toggle_node()
  local row = selected_row()
  if not row then
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
  if not state.preview_focus then
    return
  end
  state.preview_focus = false
  state.preview_top = nil
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
  map(buf, "a", M.toggle_all, "Toggle all tmux panes")
  map(buf, "gw", M.expand_working, "Expand working agents")
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
