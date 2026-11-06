local M = {}
local jobs = {}
local plugin_dir = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local helper = plugin_dir .. "/scripts/code-explain.py"
local defaults = {
  model = "gpt-6.1-terra",
  reasoning_effort = "none",
  prompt_file = plugin_dir .. "/prompts/code-explain.md",
  codex_home = vim.env.CODEX_HOME or vim.fn.expand("~/.codex"),
}
local config = defaults

local function model_settings()
  local path = vim.fn.stdpath("data") .. "/code-explain/model.json"
  if vim.fn.filereadable(path) == 1 then
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end
  return { model = config.model, effort = config.reasoning_effort }
end

local function document_project(buf)
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  local encoded = first:match("^<!%-%- code%-explain%-project: (.*) %-%->$")
  return encoded and vim.json.decode(encoded) or nil
end

local function project_root()
  local saved = document_project(0)
  if saved then
    return saved
  end
  local source = vim.api.nvim_buf_get_name(0)
  local start = source ~= "" and vim.fs.dirname(source) or vim.fn.getcwd()
  return vim.fs.root(start, ".git") or start
end

local function record_directory(project)
  local name = vim.fs.basename(project):gsub("[^%w_.-]", "_")
  return vim.fn.stdpath("data") .. "/code-explain/" .. name .. "-" .. vim.fn.sha256(project):sub(1, 12)
end

local function save(path, lines)
  vim.fn.writefile(lines, path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    local views = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
    vim.bo[buf].readonly = false
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    for win, view in pairs(views) do
      vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
    end
  end
end

local function open_record(path)
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  local target
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.b[vim.api.nvim_win_get_buf(win)].code_explain then
      target = win
      break
    end
  end
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd("rightbelow vsplit")
  end
  vim.api.nvim_win_set_buf(0, buf)
  vim.b[buf].code_explain = true
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modifiable = false
  vim.wo.wrap = true
  vim.wo.linebreak = true
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local fence
  for row, line in ipairs(lines) do
    if not fence then
      fence = line:match("^(```+)")
    elseif line == fence then
      vim.api.nvim_win_set_cursor(0, { math.min(row + 2, #lines), 0 })
      vim.cmd("normal! zt")
      break
    end
  end
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close explanation window" })
end

local function render(job, status)
  local lines = vim.list_extend({}, job.lines)
  if job.text ~= "" then
    vim.list_extend(lines, vim.split(job.text, "\n", { plain = true }))
    lines[#lines + 1] = ""
  end
  if status then
    lines[#lines + 1] = "> " .. status
  end
  return lines
end

local function finish(path, failure)
  local job = jobs[path]
  jobs[path] = nil
  local lines = render(job, failure)
  save(path, lines)
  vim.notify(failure and "Code explanation failed; the record and partial answer were kept." or "Code explanation saved.",
    failure and vim.log.levels.ERROR or vim.log.levels.INFO)
  if not failure then
    local mtime = vim.uv.fs_stat(path).mtime
    local ok = pcall(vim.api.nvim_exec_autocmds, "User", {
      pattern = "CodeExplainComplete",
      data = { path = path, content = table.concat(lines, "\n") .. "\n", version = { mtime.sec, mtime.nsec } },
    })
    if not ok then
      vim.notify("Explanation saved; a CodeExplainComplete hook failed.", vim.log.levels.WARN)
    end
  end
end

local function receive(path, job, data)
  job.pending = job.pending .. data
  while true do
    local boundary = job.pending:find("\n", 1, true)
    if not boundary then break end
    local line = job.pending:sub(1, boundary - 1)
    job.pending = job.pending:sub(boundary + 1)
    local event = vim.json.decode(line)
    if event.type == "delta" then
      job.text = job.text .. event.text
    elseif event.type == "done" then
      job.completed = true
    elseif event.type == "error" then
      job.error = event.message
    end
  end
  if not job.flush_pending then
    job.flush_pending = true
    vim.defer_fn(function()
      job.flush_pending = false
      if jobs[path] == job then
        save(path, render(job, job.error or (not job.completed and "Generating explanation..." or nil)))
      end
    end, 100)
  end
end

local function request(path, project, question)
  if jobs[path] then
    vim.notify("Wait for this explanation to finish before asking again.", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("python3") ~= 1 then
    vim.notify("Python 3.11+ is required on PATH for code explanations.", vim.log.levels.ERROR)
    return
  end

  local lines = vim.fn.readfile(path)
  if question then
    vim.list_extend(lines, { "", "## Follow-up", "", "> " .. question })
  end
  local prompt = "Saved source and conversation:\n" .. table.concat(lines, "\n")
  prompt = prompt .. (question and "\n\nAnswer the latest follow-up question." or "\n\nExplain the selected source.")
  local settings = model_settings()
  local instructions = table.concat(vim.fn.readfile(config.prompt_file), "\n")
  lines[#lines + 1] = ""
  local job = { lines = lines, text = "", pending = "" }
  jobs[path] = job
  save(path, render(job, "Generating explanation..."))
  if vim.api.nvim_buf_get_name(0) == path then
    vim.api.nvim_win_set_cursor(0, { #lines + 1, 0 })
    vim.cmd("normal! zt")
  end

  local ok, process = pcall(vim.system, { "python3", helper, "complete" }, {
    cwd = project,
    env = { CODEX_HOME = config.codex_home },
    stdin = vim.json.encode({ model = settings.model, effort = settings.effort, instructions = instructions, input = prompt }),
    text = true,
    stderr = false,
    stdout = function(_, data)
      if data then
        vim.schedule(function()
          if jobs[path] == job then receive(path, job, data) end
        end)
      end
    end,
  }, function(result)
    vim.schedule(function()
      if jobs[path] ~= job then
        return
      end
      local failure = job.error
      if not failure and (result.code ~= 0 or not job.completed) then
        failure = ("Response stream ended before completion (API helper exit %d). The helper requires Python 3.11+."):format(result.code)
      end
      finish(path, failure)
    end)
  end)
  if not ok then
    finish(path, "Could not start the API helper: " .. tostring(process))
    return
  end
  job.process = process
end

function M.explain(first, last)
  local source = vim.api.nvim_buf_get_name(0)
  local selected = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local text = table.concat(selected, "\n")
  if vim.trim(text) == "" then
    vim.notify("Select some source lines to explain.", vim.log.levels.WARN)
    return
  end
  local project = project_root()
  local directory = record_directory(project)
  vim.fn.mkdir(directory, "p", 448)
  local name = source ~= "" and vim.fs.basename(source) or "untitled"
  name = name:gsub("[^%w_.-]", "_")
  local id = vim.fn.sha256(tostring(vim.uv.hrtime())):sub(1, 8)
  local path = ("%s/%s_%s_L%d-%d_%s.md"):format(directory, os.date("%Y-%m-%d_%H-%M-%S"), name, first, last, id)
  local fence = "```"
  for ticks in text:gmatch("`+") do
    if #ticks >= #fence then
      fence = string.rep("`", #ticks + 1)
    end
  end
  local lines = {
    "<!-- code-explain-project: " .. vim.json.encode(project) .. " -->",
    "# Explain " .. name .. ":" .. first .. "-" .. last,
    "", "Source: " .. (source ~= "" and source or "[No Name]"),
    "Lines: " .. first .. "-" .. last,
    "Created: " .. os.date("%Y-%m-%d %H:%M:%S %z"),
    "", "## Source snapshot", "", fence .. vim.bo.filetype,
  }
  vim.list_extend(lines, selected)
  lines[#lines + 1] = fence
  save(path, lines)
  open_record(path)
  request(path, project)
end

function M.ask()
  local project = document_project(0)
  if not project then
    vim.notify("Open a saved explanation before asking a follow-up.", vim.log.levels.WARN)
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if jobs[path] then
    vim.notify("Wait for this explanation to finish before asking again.", vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "Ask about this code: " }, function(question)
    if question and vim.trim(question) ~= "" then
      request(path, project, question)
    end
  end)
end

function M.history()
  local directory = record_directory(project_root())
  local paths = vim.fn.glob(directory .. "/*.md", false, true)
  table.sort(paths, function(a, b) return a > b end)
  if #paths == 0 then
    vim.notify("No saved explanations for this project.")
    return
  end
  vim.ui.select(paths, {
    prompt = "Saved code explanations",
    format_item = function(path)
      return vim.fs.basename(path):gsub("_%x+%.md$", "")
    end,
  }, function(path)
    if path then
      open_record(path)
    end
  end)
end

function M.model(model, effort)
  if model then
    local directory = vim.fn.stdpath("data") .. "/code-explain"
    vim.fn.mkdir(directory, "p", 448)
    local settings = { model = model, effort = effort or (model == config.model and config.reasoning_effort or "low") }
    vim.fn.writefile({ vim.json.encode(settings) }, directory .. "/model.json")
    vim.notify("Code explanation model: " .. settings.model .. " / " .. settings.effort)
    return
  end
  if vim.fn.executable("python3") ~= 1 then
    vim.notify("Python 3.11+ is required on PATH for code explanations.", vim.log.levels.ERROR)
    return
  end
  vim.system({ "python3", helper, "models" }, { text = true, env = { CODEX_HOME = config.codex_home } }, function(result)
    vim.schedule(function()
      if result.stdout == "" then
        vim.notify("Model lookup failed. Python 3.11+ and an API-key provider are required.", vim.log.levels.ERROR)
        return
      end
      local response = vim.json.decode(result.stdout)
      if result.code ~= 0 then
        vim.notify(response.message, vim.log.levels.ERROR)
        return
      end
      local models = vim.tbl_filter(function(id)
        return not id:find("image") and not id:find("audio") and not id:find("realtime")
      end, response.models)
      table.sort(models)
      vim.ui.select(models, { prompt = "Code explanation model (current: " .. model_settings().model .. ")" }, function(selected)
        if selected then M.model(selected) end
      end)
    end)
  end)
end

function M.setup(opts)
  config = vim.tbl_extend("force", defaults, opts or {})
  vim.api.nvim_create_user_command("CodeExplain", function(opts)
    M.explain(opts.line1, opts.line2)
  end, { range = true, desc = "Explain selected lines" })
  vim.api.nvim_create_user_command("CodeExplainAsk", M.ask, { desc = "Ask about the current explanation" })
  vim.api.nvim_create_user_command("CodeExplainHistory", M.history, { desc = "Open a saved code explanation" })
  vim.api.nvim_create_user_command("CodeExplainModel", function(opts)
    if #opts.fargs > 2 then
      vim.notify("Usage: CodeExplainModel [model [reasoning_effort]]", vim.log.levels.ERROR)
      return
    end
    M.model(opts.fargs[1], opts.fargs[2])
  end, { nargs = "*", desc = "Choose the code explanation model" })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("CodeExplain", { clear = true }),
    callback = function()
      for path, job in pairs(jobs) do
        if not job.process:is_closing() then
          job.process:kill(15)
        end
        job.process:wait(1000)
        finish(path, "Interrupted: Neovim exited before the answer was complete.")
      end
    end,
  })
end

return M
