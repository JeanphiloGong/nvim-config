-- Run with: nvim --headless -i NONE -n -c 'lua dofile("test/code-explain-config.lua")'
local temp = vim.fn.tempname() .. " code-explain-config"
local original_path = vim.env.PATH
local original_data = vim.env.XDG_DATA_HOME

local ok, err = xpcall(function()
  assert(not package.loaded.code_explain, "Plugin loaded before a command or key was used")
  assert(vim.fn.exists(":CodeExplain") == 2, "Lazy command was not registered")
  assert(vim.fn.maparg("<leader>ae", "x") ~= "", "Lazy visual key was not registered")
  vim.fn.mkdir(temp .. "/bin", "p")
  vim.fn.mkdir(temp .. "/project/.git", "p")
  vim.env.PATH = temp .. "/bin:" .. original_path
  vim.env.XDG_DATA_HOME = temp .. "/data"
  vim.fn.writefile({
    "#!/bin/sh",
    'if [ ! -f "$1" ]; then exit 9; fi',
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
  print("Lazy first visual selection, local plugin resources, source preservation, and history: OK")
end, debug.traceback)

if package.loaded.code_explain then
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "CodeExplain" })
end
vim.env.PATH = original_path
vim.env.XDG_DATA_HOME = original_data
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
