-- Run with: nvim --headless -i NONE -n -c 'lua dofile("test/code-explain-config.lua")'
local temp = vim.fn.tempname() .. " code-explain-config"
local original_path = vim.env.PATH
local original_data = vim.env.XDG_DATA_HOME
local original_notify = vim.notify
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end

local ok, err = xpcall(function()
  assert(not package.loaded.code_explain, "Plugin loaded before a command or key was used")
  assert(vim.fn.exists(":CodeExplain") == 2, "Lazy command was not registered")
  assert(vim.fn.maparg("<leader>ae", "x") ~= "", "Lazy visual key was not registered")
  vim.fn.mkdir(temp .. "/bin", "p")
  vim.fn.mkdir(temp .. "/project/.git", "p")
  vim.env.PATH = temp .. "/bin:" .. original_path
  vim.env.XDG_DATA_HOME = temp .. "/data"
  vim.g.learning_wiki_vault = temp .. "/Learning Wiki"
  vim.env.CODE_EXPLAIN_TEST_WIKI = temp .. "/wiki-snapshot"
  vim.fn.writefile({
    "#!/bin/sh",
    'if [ ! -f "$1" ]; then exit 9; fi',
    'if [ "$2" != complete ]; then',
    '  cat > "$CODE_EXPLAIN_TEST_WIKI"',
    '  printf "%s\\n" "$@" > "$CODE_EXPLAIN_TEST_WIKI.args"',
    '  : > "$CODE_EXPLAIN_TEST_WIKI.done"',
    '  if [ "$CODE_EXPLAIN_TEST_WIKI_FAIL" = 1 ]; then echo "Fixture Wiki failed." >&2; exit 7; fi',
    '  exit 0',
    'fi',
    "cat > /dev/null",
    "printf '%s\\n' '{\"type\":\"delta\",\"text\":\"Configured plugin answer.\"}' '{\"type\":\"done\"}'",
  }, temp .. "/bin/python3")
  vim.fn.setfperm(temp .. "/bin/python3", "rwx------")
  local source = temp .. "/project/example.go"
  vim.cmd.edit(vim.fn.fnameescape(source))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "func example() string {", '    return "value"', "}", "// outside" })
  local source_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_feedkeys("Vj ae", "xt", false)
  local record = vim.api.nvim_buf_get_name(0)
  assert(record ~= source, "First visual key did not open an explanation")
  assert(vim.wait(5000, function()
    return table.concat(vim.fn.readfile(record), "\n"):find("Configured plugin answer.", 1, true) ~= nil
  end, 10), "The locally installed plugin did not save its answer")
  local text = table.concat(vim.fn.readfile(record), "\n")
  assert(text:find("Lines: 1-2", 1, true), "Lazy loading lost the selected range")
  assert(not text:find("// outside", 1, true), "The selection included outside lines")
  assert(vim.wait(5000, function() return vim.fn.filereadable(vim.env.CODE_EXPLAIN_TEST_WIKI .. ".done") == 1 end, 10),
    "The successful explanation did not start a Wiki update")
  local snapshot = vim.json.decode(table.concat(vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_WIKI), "\n"))
  assert(snapshot.path == record and snapshot.content == text .. "\n", "Wiki did not receive the final immutable snapshot")
  assert(not snapshot.content:find("Generating explanation...", 1, true), "Wiki received a pending record")
  local wiki_args = vim.fn.readfile(vim.env.CODE_EXPLAIN_TEST_WIKI .. ".args")
  assert(wiki_args[1] == vim.fn.stdpath("config") .. "/tools/learning-wiki/wiki.py", "Host selected the wrong Wiki tool")
  assert(wiki_args[2] == "--vault" and wiki_args[3] == vim.g.learning_wiki_vault, "Wiki lost the vault path with spaces")
  assert(vim.bo[source_buf].modified, "The source buffer was written")
  assert(vim.fn.filereadable(source) == 0, "A source file was created")
  local module = assert(package.loaded.code_explain)
  assert(debug.getinfo(module.setup, "S").source:find("/local/code-explain.nvim/lua/code_explain.lua", 1, true),
    "The host loaded a module outside the plugin directory")
  vim.cmd.close()
  vim.ui.select = function(items, _, callback)
    assert(#items == 1 and items[1] == record)
    callback(items[1])
  end
  vim.cmd.CodeExplainHistory()
  assert(vim.api.nvim_buf_get_name(0) == record, "The host key/command setup could not reopen history")
  vim.fn.delete(vim.env.CODE_EXPLAIN_TEST_WIKI)
  vim.fn.delete(vim.env.CODE_EXPLAIN_TEST_WIKI .. ".done")
  vim.g.learning_wiki_enabled = false
  vim.api.nvim_exec_autocmds("User", { pattern = "CodeExplainComplete", data = snapshot })
  assert(not vim.wait(100, function() return vim.fn.filereadable(vim.env.CODE_EXPLAIN_TEST_WIKI .. ".done") == 1 end, 10),
    "Disabled Wiki still started a process")
  vim.g.learning_wiki_enabled = true
  vim.env.CODE_EXPLAIN_TEST_WIKI_FAIL = "1"
  vim.api.nvim_exec_autocmds("User", { pattern = "CodeExplainComplete", data = snapshot })
  assert(vim.wait(5000, function()
    return table.concat(notices, "\n"):find("Fixture Wiki failed.", 1, true) ~= nil
  end, 10), "Wiki failure did not produce a warning")
  assert(table.concat(vim.fn.readfile(record), "\n") == text, "Wiki failure changed the explanation")

  vim.fn.mkdir(vim.g.learning_wiki_vault .. "/Concepts", "p")
  vim.fn.writefile({ "# Learning Wiki", "", "[Boolean logic](Concepts/go-booleans.md)" }, vim.g.learning_wiki_vault .. "/Learning.md")
  vim.fn.writefile({ "# Boolean logic" }, vim.g.learning_wiki_vault .. "/Concepts/go-booleans.md")
  local tabs = #vim.api.nvim_list_tabpages()
  vim.api.nvim_feedkeys(" aw", "xt", false)
  assert(#vim.api.nvim_list_tabpages() == tabs + 1, "Wiki did not open in a new tab")
  assert(vim.api.nvim_buf_get_name(0) == vim.g.learning_wiki_vault .. "/Learning.md", "Wiki key opened the wrong index")
  vim.api.nvim_win_set_cursor(0, { 3, 15 })
  vim.cmd("normal! gf")
  assert(vim.api.nvim_buf_get_name(0) == vim.g.learning_wiki_vault .. "/Concepts/go-booleans.md", "Relative Markdown navigation failed")
  assert(vim.bo[source_buf].modified, "Opening the Wiki wrote the source buffer")
  print("Lazy selection, background Wiki snapshots, failure/disable isolation, history, and Wiki navigation: OK")
end, debug.traceback)

if package.loaded.code_explain then
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "CodeExplain" })
end
vim.env.PATH = original_path
vim.env.XDG_DATA_HOME = original_data
vim.notify = original_notify
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
