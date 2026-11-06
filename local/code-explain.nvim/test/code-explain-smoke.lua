-- Run with: nvim --headless -u NONE -l test/code-explain-smoke.lua
local temp = vim.fn.tempname() .. " code-explain"
local original_path = vim.env.PATH
local original_data = vim.env.XDG_DATA_HOME
local plugin_dir = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ":p")))
local notices = {}
local completions = {}
vim.api.nvim_create_autocmd("User", {
  pattern = "CodeExplainComplete",
  callback = function(event) completions[#completions + 1] = event.data end,
})
vim.notify = function(message)
  notices[#notices + 1] = message
end

local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function contains(text, expected)
  assert(text:find(expected, 1, true), "Missing text: " .. expected)
end

local function wait_for_answer(path, expected)
  assert(vim.wait(5000, function()
    return read(path):find(expected, 1, true) ~= nil
  end, 10), "Answer was not saved: " .. expected)
end

local ok, err = xpcall(function()
  local bin = temp .. "/bin"
  local project = temp .. "/project space"
  local source = project .. "/session $(literal).go"
  vim.fn.mkdir(bin, "p")
  vim.fn.mkdir(project .. "/.git", "p")
  vim.env.XDG_DATA_HOME = temp .. "/data"
  vim.env.PATH = bin .. ":" .. original_path
  vim.env.CODE_EXPLAIN_TEST_ARGS = temp .. "/args"
  vim.env.CODE_EXPLAIN_TEST_PROMPT = temp .. "/prompt"
  vim.fn.writefile(vim.split([=[#!/bin/sh
printf '%s\n' "$@" > "$CODE_EXPLAIN_TEST_ARGS"
pwd > "$CODE_EXPLAIN_TEST_ARGS.cwd"
printf '%s\n' "$CODEX_HOME" > "$CODE_EXPLAIN_TEST_ARGS.codex-home"
if [ ! -f "$1" ]; then exit 9; fi
if [ "$2" = models ]; then
  if [ "$CODE_EXPLAIN_TEST_MODELS_EMPTY" = 1 ]; then exit 1; fi
  printf '%s\n' '{"models":["gpt-6.1-sol","gpt-6.1-terra","gpt-image-2","gpt-4o-audio-preview"]}'
  exit 0
fi
cat > "$CODE_EXPLAIN_TEST_PROMPT"
if [ "$CODE_EXPLAIN_TEST_EMPTY" = 1 ]; then
  printf '%s\n' '{"type":"error","message":"The model returned no explanation."}'
  exit 1
fi
printf '%s\n' '{"type":"delta","text":"A streamed prefix. "}'
if [ -n "$CODE_EXPLAIN_TEST_RELEASE" ]; then
  while [ ! -f "$CODE_EXPLAIN_TEST_RELEASE" ]; do sleep 0.02; done
fi
if [ "$CODE_EXPLAIN_TEST_FAIL" = 1 ]; then
  printf '%s\n' '{"type":"delta","text":"Partial response before failure."}'
  printf '%s\n' 'private-provider-diagnostic' >&2
  exit 7
fi
printf '{"type":"delta","text":"%s"}\n' "${CODE_EXPLAIN_TEST_ANSWER:-A saved explanation of Resolve.}"
printf '%s\n' '{"type":"done"}'
]=], "\n"), bin .. "/python3")
  vim.fn.setfperm(bin .. "/python3", "rwx------")
  vim.fn.writefile({ "package example", "// original disk contents" }, source)

  vim.opt.rtp:prepend(plugin_dir)
  vim.g.mapleader = " "
  local explain = require("code_explain")
  explain.setup()
  assert(vim.fn.maparg("<leader>ae", "x") == "", "Plugin assigned a global visual mapping")
  assert(vim.fn.maparg("<leader>aa", "n") == "", "Plugin assigned a global follow-up mapping")
  vim.keymap.set("x", "<leader>ae", ":CodeExplain<cr>", { silent = true })
  assert(vim.fn.exists(":CodeExplain") == 2, "CodeExplain is not registered")
  vim.cmd.edit(vim.fn.fnameescape(source))
  vim.bo.filetype = "go"
  local source_buf = vim.api.nvim_get_current_buf()
  local lines = {
    "package example", "",
    "func (s Session) Resolve(now time.Time) (User, error) {",
    "\tif !s.User.Active { return User{}, ErrUnauthenticated }",
    "\treturn s.User, nil",
    "}", "// outside the selection",
  }
  vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, lines)
  vim.fn.setreg('"', "keep this register")
  vim.env.CODE_EXPLAIN_TEST_RELEASE = temp .. "/first-release"
  vim.api.nvim_win_set_cursor(0, { 6, 0 })
  vim.api.nvim_feedkeys("Vkkk ae", "xt", false)

  local record = vim.api.nvim_buf_get_name(0)
  assert(record ~= source and record:match("%.md$"), "Visual mapping did not open Markdown")
  assert(#vim.api.nvim_tabpage_list_wins(0) == 2, "Explanation did not split the window")
  assert(vim.bo.filetype == "markdown", "Explanation filetype is not Markdown")
  local current_line = vim.api.nvim_get_current_line()
  assert(current_line:find("Generating explanation...", 1, true) or current_line:find("A streamed prefix.", 1, true),
    "Explanation did not open at the answer")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source_buf, 0, -1, false), lines), "Source buffer changed")
  assert(vim.bo[source_buf].modified, "Unsaved source changes were lost")
  assert(read(source) == "package example\n// original disk contents", "Source file was written")
  assert(vim.fn.getreg('"') == "keep this register", "Selection overwrote the register")
  wait_for_answer(record, "A streamed prefix.")
  assert(#completions == 0, "Streaming emitted a completion event")
  assert(not read(record):find("A saved explanation of Resolve.", 1, true), "Answer was buffered until completion")
  vim.fn.writefile({}, vim.env.CODE_EXPLAIN_TEST_RELEASE)
  vim.env.CODE_EXPLAIN_TEST_RELEASE = nil
  wait_for_answer(record, "A saved explanation of Resolve.")
  assert(not vim.fn.execute("messages"):find("W10", 1, true), "Updating the explanation produced a readonly warning")
  local document = read(record)
  assert(#completions == 1 and completions[1].path == record, "Successful save did not emit its path")
  assert(completions[1].content == document .. "\n", "Completion did not carry the exact saved snapshot")
  local mtime = vim.uv.fs_stat(record).mtime
  assert(vim.deep_equal(completions[1].version, { mtime.sec, mtime.nsec }), "Completion version differs from the save")
  contains(document, source)
  contains(document, "3-6")
  contains(document, "return s.User, nil")
  assert(not document:find("outside the selection", 1, true), "Selection included extra lines")
  contains(read(vim.env.CODE_EXPLAIN_TEST_PROMPT), "return s.User, nil")
  local payload = vim.json.decode(read(vim.env.CODE_EXPLAIN_TEST_PROMPT))
  contains(payload.instructions, "Always respond in English")
  assert(payload.model == "gpt-6.1-terra" and payload.effort == "none", "Requested reasoning default is not used")
  assert(not document:find("## Explanation", 1, true), "Extra explanation heading was saved")
  assert(not document:find("Model:", 1, true), "Model metadata was saved")
  assert(not document:find("service tier", 1, true), "Service tier metadata was saved")
  assert(not document:find("Service tier", 1, true), "Service tier footer was saved")
  vim.api.nvim_feedkeys("q", "xt", false)
  assert(vim.api.nvim_get_current_buf() == source_buf, "Closing did not return to source")
  assert(vim.fn.filereadable(record) == 1, "Closing deleted the record")
  print("Visual explanation, source snapshot, English, fast defaults, and durable Markdown: OK")

  vim.ui.select = function(items, opts, callback)
    assert(#items == 1 and items[1] == record, "History did not list this project's record")
    assert(not opts.format_item(record):find("%.md$"), "History label includes the internal file suffix")
    callback(items[1])
  end
  vim.cmd.CodeExplainHistory()
  assert(vim.api.nvim_buf_get_name(0) == record, "History did not reopen the explanation")
  contains(vim.api.nvim_get_current_line(), "A streamed prefix.")
  vim.ui.input = function(_, callback) callback(nil) end
  local before_cancel = read(record)
  vim.cmd.CodeExplainAsk()
  assert(read(record) == before_cancel, "Cancelling input modified the record")

  vim.env.CODE_EXPLAIN_TEST_ANSWER = "A follow-up answer about value copies."
  local broken_hook = vim.api.nvim_create_autocmd("User", {
    pattern = "CodeExplainComplete",
    callback = function() error("Consumer failure") end,
  })
  vim.env.CODE_EXPLAIN_TEST_RELEASE = temp .. "/release"
  vim.ui.input = function(_, callback) callback("Why is the user copied?") end
  vim.cmd.CodeExplainAsk()
  wait_for_answer(record, "A streamed prefix.")
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  local input_calls = 0
  vim.ui.input = function() input_calls = input_calls + 1 end
  vim.cmd.CodeExplainAsk()
  assert(input_calls == 0, "A second request was allowed while generating")
  vim.fn.writefile({}, vim.env.CODE_EXPLAIN_TEST_RELEASE)
  wait_for_answer(record, "A follow-up answer about value copies.")
  vim.api.nvim_del_autocmd(broken_hook)
  assert(#completions == 2, "Follow-up did not emit a completion")
  assert(completions[1].content == document .. "\n", "Follow-up changed the earlier event snapshot")
  contains(completions[2].content, "A follow-up answer about value copies.")
  contains(read(record), "A follow-up answer about value copies.")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "Answer update moved the reader's cursor")
  contains(read(record), "Why is the user copied?")
  local follow_up = read(vim.env.CODE_EXPLAIN_TEST_PROMPT)
  contains(follow_up, "return s.User, nil")
  contains(follow_up, "A saved explanation of Resolve.")
  contains(follow_up, "Why is the user copied?")
  vim.env.CODE_EXPLAIN_TEST_RELEASE = nil
  print("History, cancelled input, follow-up context, and request serialization: OK")

  vim.env.CODE_EXPLAIN_TEST_FAIL = "1"
  vim.ui.input = function(_, callback) callback("A question while the provider is offline") end
  vim.cmd.CodeExplainAsk()
  wait_for_answer(record, "API helper exit 7")
  contains(read(record), "A follow-up answer about value copies.")
  contains(read(record), "Partial response before failure.")
  assert(not read(record):find("private-provider-diagnostic", 1, true), "Raw provider logs leaked into the record")
  vim.env.CODE_EXPLAIN_TEST_FAIL = nil
  vim.env.CODE_EXPLAIN_TEST_EMPTY = "1"
  vim.ui.input = function(_, callback) callback("A question with an empty response") end
  vim.cmd.CodeExplainAsk()
  wait_for_answer(record, "The model returned no explanation.")
  vim.env.CODE_EXPLAIN_TEST_EMPTY = nil
  assert(#completions == 2, "Failed or empty generation emitted a completion")
  print("Failure and empty-response handling preserve the existing conversation: OK")

  vim.api.nvim_feedkeys("q", "xt", false)
  vim.env.CODE_EXPLAIN_TEST_RELEASE = temp .. "/release-closed"
  vim.env.CODE_EXPLAIN_TEST_ANSWER = "Answer saved after closing the window."
  vim.cmd("3,6CodeExplain")
  local closed_record = vim.api.nvim_buf_get_name(0)
  assert(closed_record ~= record, "A new selection reused the previous document")
  local closed_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_feedkeys("q", "xt", false)
  vim.api.nvim_buf_delete(closed_buf, { force = true })
  vim.fn.writefile({}, vim.env.CODE_EXPLAIN_TEST_RELEASE)
  wait_for_answer(closed_record, "Answer saved after closing the window.")
  vim.env.CODE_EXPLAIN_TEST_RELEASE = nil
  print("Closing or unloading the explanation buffer still saves the result: OK")

  vim.cmd("3,6CodeExplain")
  local reused_window = vim.api.nvim_get_current_win()
  local extra_record = vim.api.nvim_buf_get_name(0)
  wait_for_answer(extra_record, "Answer saved after closing the window.")
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == source_buf then
      vim.api.nvim_set_current_win(win)
      break
    end
  end
  vim.cmd("3,6CodeExplain")
  local reused_record = vim.api.nvim_buf_get_name(0)
  wait_for_answer(reused_record, "Answer saved after closing the window.")
  assert(#vim.api.nvim_tabpage_list_wins(0) == 2, "Explanation windows accumulated")
  assert(vim.api.nvim_get_current_win() == reused_window, "Existing explanation window was not reused")
  vim.api.nvim_feedkeys("q", "xt", false)

  local preferences = vim.fn.stdpath("data") .. "/code-explain/model.json"
  local picked = false
  vim.ui.select = function(items, _, callback)
    assert(vim.tbl_contains(items, "gpt-6.1-sol"), "Model picker omitted a provider model")
    assert(not vim.tbl_contains(items, "gpt-image-2"), "Model picker offered an image model")
    callback("gpt-6.1-sol")
    picked = true
  end
  vim.cmd.CodeExplainModel()
  assert(vim.wait(5000, function() return picked end, 10), "Model picker did not open")
  local selected_settings = vim.json.decode(read(preferences))
  assert(selected_settings.model == "gpt-6.1-sol" and selected_settings.effort == "low", "Selected model was not saved")
  vim.env.CODE_EXPLAIN_TEST_MODELS_EMPTY = "1"
  local before_model_error = #notices
  vim.cmd.CodeExplainModel()
  assert(vim.wait(5000, function() return #notices > before_model_error end, 10), "Model-list process failure was not reported")
  contains(notices[#notices], "Python 3.11+")
  vim.env.CODE_EXPLAIN_TEST_MODELS_EMPTY = nil

  local restart_script = temp .. "/restart.lua"
  vim.env.CODE_EXPLAIN_TEST_PLUGIN = plugin_dir
  vim.env.CODE_EXPLAIN_TEST_SOURCE = source
  vim.env.CODE_EXPLAIN_TEST_RECORD = record
  vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD = temp .. "/shutdown-record"
  vim.env.CODE_EXPLAIN_TEST_ANSWER = "An answer after restarting Neovim."
  vim.fn.writefile(vim.split([=[vim.opt.rtp:prepend(vim.env.CODE_EXPLAIN_TEST_PLUGIN)
vim.g.mapleader = " "
require("code_explain").setup()
vim.cmd.edit(vim.fn.fnameescape(vim.env.CODE_EXPLAIN_TEST_SOURCE))
vim.ui.select = function(items, _, callback)
  assert(vim.tbl_contains(items, vim.env.CODE_EXPLAIN_TEST_RECORD))
  callback(vim.env.CODE_EXPLAIN_TEST_RECORD)
end
vim.cmd.CodeExplainHistory()
vim.cmd.cd(vim.fn.fnameescape(vim.env.CODE_EXPLAIN_TEST_PLUGIN))
vim.ui.input = function(_, callback) callback("Continue the explanation after restarting") end
vim.cmd.CodeExplainAsk()
assert(vim.wait(5000, function()
  local text = table.concat(vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_RECORD), "\n")
  return text:find("An answer after restarting Neovim.", 1, true) ~= nil
end, 10))
local prompt = table.concat(vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_PROMPT), "\n")
assert(prompt:find("return s.User, nil", 1, true))
assert(prompt:find("A follow-up answer about value copies.", 1, true))
assert(prompt:find("Continue the explanation after restarting", 1, true))
local settings = vim.json.decode(prompt)
assert(settings.model == "gpt-6.1-sol" and settings.effort == "low")
assert(vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_ARGS .. ".cwd")[1] == vim.fs.dirname(vim.env.CODE_EXPLAIN_TEST_SOURCE))
vim.cmd.close()
vim.api.nvim_create_autocmd("User", {
  pattern = "CodeExplainComplete",
  callback = function() vim.fn.writefile({ "unexpected" }, vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD .. ".event") end,
})
vim.env.CODE_EXPLAIN_TEST_RELEASE = vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD .. ".gate"
vim.fn.delete(vim.env.CODE_EXPLAIN_TEST_ARGS)
vim.cmd("1CodeExplain")
vim.fn.writefile({ vim.api.nvim_buf_get_name(0) }, vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD)
assert(vim.wait(5000, function() return vim.fn.filereadable(vim.env.CODE_EXPLAIN_TEST_ARGS) == 1 end, 10))
vim.cmd("qa!")
]=], "\n"), restart_script)
  local restarted = vim.system({ vim.v.progpath, "--headless", "-u", "NONE", "-l", restart_script },
    { cwd = temp, text = true }):wait(15000)
  assert(restarted.code == 0, "Restart check failed: " .. (restarted.stderr or ""))
  contains(read(record), "An answer after restarting Neovim.")
  local interrupted = vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD)[1]
  contains(read(interrupted), "Interrupted: Neovim exited")
  assert(vim.fn.filereadable(vim.env.CODE_EXPLAIN_TEST_SHUTDOWN_RECORD .. ".event") == 0,
    "Editor shutdown emitted a successful completion")
  assert(not read(interrupted):find("Generating explanation...", 1, true), "Shutdown left a stale pending status")
  print("Fresh Neovim restores context and model choice; shutdown preserves unfinished requests: OK")

  local other_project = temp .. "/other project"
  vim.fn.mkdir(other_project .. "/.git", "p")
  vim.cmd.edit(vim.fn.fnameescape(other_project .. "/other.go"))
  local select_calls = 0
  vim.ui.select = function() select_calls = select_calls + 1 end
  vim.cmd.CodeExplainHistory()
  assert(select_calls == 0, "History mixed records from different projects")
  print("Project histories are separate: OK")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
  local empty_buf = vim.api.nvim_get_current_buf()
  vim.cmd.CodeExplain()
  assert(vim.api.nvim_get_current_buf() == empty_buf, "Empty selection opened a record")
  contains(notices[#notices], "Select some source lines")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "```go", "func example() {}", "```" })
  vim.bo.filetype = "markdown"
  vim.cmd("1,3CodeExplain")
  local fenced_record = vim.api.nvim_buf_get_name(0)
  wait_for_answer(fenced_record, "An answer after restarting Neovim.")
  contains(read(fenced_record), "````markdown\n```go\nfunc example() {}\n```\n````")
  vim.api.nvim_feedkeys("q", "xt", false)

  local custom_prompt = temp .. "/teaching.md"
  local custom_home = temp .. "/codex home"
  vim.fn.writefile({ "Teach from this custom prompt." }, custom_prompt)
  vim.fn.delete(preferences)
  explain.setup({ model = "configured-model", reasoning_effort = "high", prompt_file = custom_prompt, codex_home = custom_home })
  vim.cmd("1,3CodeExplain")
  wait_for_answer(vim.api.nvim_buf_get_name(0), "An answer after restarting Neovim.")
  local configured = vim.json.decode(read(vim.env.CODE_EXPLAIN_TEST_PROMPT))
  assert(configured.model == "configured-model" and configured.effort == "high", "Setup model settings were ignored")
  assert(configured.instructions == "Teach from this custom prompt.", "Custom prompt was not loaded")
  assert(read(vim.env.CODE_EXPLAIN_TEST_ARGS .. ".codex-home") == custom_home, "Configured Codex home was not passed to the helper")
  vim.api.nvim_feedkeys("q", "xt", false)
  vim.fn.writefile({ "Teach from the edited prompt." }, custom_prompt)
  vim.cmd("1,3CodeExplain")
  wait_for_answer(vim.api.nvim_buf_get_name(0), "An answer after restarting Neovim.")
  assert(vim.json.decode(read(vim.env.CODE_EXPLAIN_TEST_PROMPT)).instructions == "Teach from the edited prompt.",
    "Prompt edits did not apply to the next request")
  vim.api.nvim_feedkeys("q", "xt", false)
  explain.setup()
  print("Setup options, Codex home, and prompt edits work without the owner's configuration: OK")

  local before_missing = #notices
  vim.fn.rename(bin .. "/python3", bin .. "/python3-disabled")
  vim.env.PATH = bin
  vim.cmd("1,3CodeExplain")
  contains(notices[before_missing + 1], "Python 3.11+")
  assert(pcall(vim.cmd.CodeExplainModel), "Missing Python crashed the model picker")
  vim.env.PATH = bin .. ":" .. original_path
  vim.fn.rename(bin .. "/python3-disabled", bin .. "/python3")
  assert(not table.concat(notices, "\n"):find("private-provider-diagnostic", 1, true), "Provider logs leaked through notifications")
  print("Empty selections, nested Markdown fences, and missing Python are handled: OK")
end, debug.traceback)

vim.api.nvim_exec_autocmds("VimLeavePre", {})
vim.env.PATH = original_path
vim.env.XDG_DATA_HOME = original_data
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
