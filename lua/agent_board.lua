local M = {}

local state = {
  buf = nil,
  selected = 1,
  show_all = false,
  panes = {},
  line_to_index = {},
  row_lines = {},
  generated_at = nil,
}

local ns = vim.api.nvim_create_namespace("agent_board")

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

local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local data = run_scan()
  if not data then
    return
  end

  state.panes = data.panes or {}
  state.generated_at = data.generated_at
  if #state.panes == 0 then
    state.selected = 1
  elseif state.selected > #state.panes then
    state.selected = #state.panes
  elseif state.selected < 1 then
    state.selected = 1
  end

  state.line_to_index = {}
  state.row_lines = {}

  local counts = data.counts or {}
  local lines = {}
  table.insert(lines, "AgentBoard")
  table.insert(
    lines,
    string.format(
      "blocked=%s working=%s done=%s idle=%s unknown=%s  scope=%s",
      counts.blocked or 0,
      counts.working or 0,
      counts.done or 0,
      counts.idle or 0,
      counts.unknown or 0,
      state.show_all and "all panes" or "agents"
    )
  )
  table.insert(lines, "")
  table.insert(lines, string.format("%-9s %-9s %-28s %-8s %s", "STATE", "AGENT", "TARGET", "PANE", "LABEL"))
  table.insert(lines, string.rep("-", 88))

  for index, pane in ipairs(state.panes) do
    local source = pane.source == "report" and "*" or " "
    local line = string.format(
      "%s%-8s %-9s %-28s %-8s %s",
      source,
      pane.state or "unknown",
      pane.agent or "-",
      truncate(pane_location(pane), 28),
      pane.pane_id or "-",
      truncate(pane.label or "", 80)
    )
    table.insert(lines, line)
    state.line_to_index[#lines] = index
    state.row_lines[index] = #lines
  end

  if #state.panes == 0 then
    table.insert(lines, "No agent panes detected. Press a to include all tmux panes.")
  end

  table.insert(lines, "")
  table.insert(lines, "Keys: C-j/C-k move  C-h/C-l move  Enter/Space jump  click select  double-click jump  r refresh  a all  q quit")
  table.insert(lines, "* means state came from an agent report hook.")

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardHeader", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardDim", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "AgentBoardHeader", 3, 0, -1)

  for index, pane in ipairs(state.panes) do
    local line = state.row_lines[index]
    if line then
      vim.api.nvim_buf_add_highlight(state.buf, ns, state_hl(pane.state), line - 1, 0, 9)
    end
  end

  local selected_line = state.row_lines[state.selected]
  if selected_line and vim.api.nvim_get_current_buf() == state.buf then
    pcall(vim.api.nvim_win_set_cursor, 0, { selected_line, 0 })
  end
end

function M.refresh()
  render()
end

function M.move(delta)
  if #state.panes == 0 then
    return
  end
  state.selected = math.max(1, math.min(#state.panes, state.selected + delta))
  local line = state.row_lines[state.selected]
  if line then
    pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  end
end

local function select_line(line)
  local index = state.line_to_index[line]
  if not index then
    return false
  end
  state.selected = index
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  return true
end

function M.select_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  select_line(cursor[1])
end

local function tmux(args)
  local cmd = { "tmux" }
  vim.list_extend(cmd, args)
  vim.fn.system(cmd)
end

function M.jump()
  local pane = state.panes[state.selected]
  if not pane then
    return
  end

  tmux({ "switch-client", "-t", pane.session })
  tmux({ "select-window", "-t", pane.session .. ":" .. pane.window })
  tmux({ "select-pane", "-t", pane.pane_id })

  if vim.env.TMUX_AGENT_BOARD_QUIT_ON_JUMP == "1" then
    vim.schedule(function()
      vim.cmd("qa!")
    end)
  else
    notify("Jumped to " .. pane_location(pane))
  end
end

function M.toggle_all()
  state.show_all = not state.show_all
  state.selected = 1
  render()
end

function M.close()
  if vim.env.TMUX_AGENT_BOARD_QUIT_ON_JUMP == "1" then
    vim.cmd("qa!")
    return
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.cmd("bdelete!")
  end
end

local function map(buf, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
end

local function attach_maps(buf)
  map(buf, "q", M.close, "Close AgentBoard")
  map(buf, "r", M.refresh, "Refresh AgentBoard")
  map(buf, "a", M.toggle_all, "Toggle all tmux panes")
  map(buf, "j", function()
    M.move(1)
  end, "Next agent")
  map(buf, "k", function()
    M.move(-1)
  end, "Previous agent")
  map(buf, "<Down>", function()
    M.move(1)
  end, "Next agent")
  map(buf, "<Up>", function()
    M.move(-1)
  end, "Previous agent")
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
  map(buf, "<CR>", M.jump, "Jump to pane")
  map(buf, "<Space>", M.jump, "Jump to pane")
  map(buf, "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == vim.api.nvim_get_current_win() then
      select_line(pos.line)
    end
  end, "Select agent")
  map(buf, "<2-LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == vim.api.nvim_get_current_win() and select_line(pos.line) then
      M.jump()
    end
  end, "Jump to pane")
end

function M.open()
  ensure_highlights()
  vim.opt.mouse = "a"

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "agent-board"
    vim.api.nvim_buf_set_name(state.buf, "AgentBoard")
    attach_maps(state.buf)
  end

  vim.api.nvim_set_current_buf(state.buf)
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = true
  render()
end

function M.setup()
  vim.api.nvim_create_user_command("AgentBoard", function()
    M.open()
  end, { desc = "Open tmux agent board" })
end

return M
