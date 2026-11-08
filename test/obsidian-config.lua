-- Run with: nvim --headless -i NONE -n -c 'lua dofile("test/obsidian-config.lua")'
local temp = vim.fn.tempname() .. " obsidian notes"
local vault = temp .. "/Obsidian Vault"
local project = temp .. "/other project"
local notices = {}
local original_notify = vim.notify
vim.notify = function(message, level)
  if level and level >= vim.log.levels.WARN then notices[#notices + 1] = message end
end

local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function key(suffix)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc> n" .. suffix, true, false, true), "xt", false)
end

local function picker_with(count)
  assert(vim.wait(5000, function() return vim.bo.filetype == "TelescopePrompt" end, 10), "Note picker did not open")
  local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
  assert(vim.wait(5000, function() return picker.manager and picker.manager:num_results() >= count end, 10),
    "Note picker did not return expected results: " .. vim.inspect({count = picker.manager and picker.manager:num_results(),
      first = picker.manager and picker.manager:get_entry(1), prompt = picker:_get_prompt(), notices = notices}))
  return picker
end

local function paths(picker)
  local result = {}
  for entry in picker.manager:iter() do
    local item = entry.obsidian_item or entry
    local path = type(item) == "string" and item or item.path or item.filename
    result[path] = true
  end
  return result
end

local ok, err = xpcall(function()
  assert(not package.loaded.obsidian, "Obsidian loaded before a note, command or key was used")
  assert(vim.fn.exists(":Obsidian") == 2, "Lazy did not register the Obsidian command")
  for _, suffix in ipairs({ "f", "s", "n", "d", "b", "e", "h" }) do
    assert(vim.fn.maparg("<leader>n" .. suffix, "n") ~= "", "Missing note key: " .. suffix)
  end
  vim.o.columns, vim.o.lines = 160, 50
  vim.fn.mkdir(vault .. "/00-收件箱", "p")
  vim.fn.mkdir(vault .. "/04-CodeWiki/Concepts", "p")
  vim.fn.mkdir(project, "p")
  vim.fn.writefile({ "package example" }, project .. "/main.go")
  local concept = vault .. "/04-CodeWiki/Concepts/go-slices.md"
  local inbox = vault .. "/00-收件箱/learning.md"
  vim.fn.writefile({ "# My notes", "", "[Go slices](04-CodeWiki/Concepts/go-slices.md)" }, vault .. "/Home.md")
  vim.fn.writefile({ "# Learning", "", "[[04-CodeWiki/Concepts/go-slices]]" }, inbox)
  vim.fn.writefile({ "# Go slices", "", "<!-- learning-wiki:source:fixture:start -->",
    "A slice shares backing storage.", "<!-- learning-wiki:source:fixture:end -->" }, concept)
  local original_concept = read(concept)
  local plugin = assert(require("lazy.core.config").plugins["obsidian.nvim"])
  local configure = plugin.opts
  plugin.opts = function(...)
    local opts = configure(...)
    opts.workspaces[1].path = vault
    return opts
  end

  vim.cmd.tcd(vim.fn.fnameescape(project))
  vim.cmd.edit(vim.fn.fnameescape(project .. "/main.go"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "package example // Unsaved code stays available." })
  local source = vim.api.nvim_get_current_buf()
  local source_tab = vim.api.nvim_get_current_tabpage()
  key("h")
  assert(vim.api.nvim_buf_get_name(0) == vault .. "/Home.md", "Personal home key opened another vault")
  assert(vim.fn.getcwd() == vault, "Personal home retained the other project's directory")
  assert(vim.bo[source].modified and vim.api.nvim_buf_get_lines(source, 0, 1, false)[1]
    == "package example // Unsaved code stays available.")
  vim.api.nvim_set_current_tabpage(source_tab)
  assert(vim.fn.getcwd() == project, "Personal home changed the code tab's directory")
  key("e")
  assert(vim.api.nvim_get_current_tabpage() ~= source_tab, "Note directory replaced the code tab")
  local tree = require("neo-tree.sources.manager").get_state("filesystem")
  assert(vim.wait(5000, function()
    return tree.path == vault and tree.winid and vim.api.nvim_win_is_valid(tree.winid)
      and tree.tree and tree.tree:get_node(vault .. "/Home.md") ~= nil
  end, 10), "Note directory did not open the vault from another project")
  assert(vim.bo.filetype == "neo-tree" and vim.fn.getcwd() == vault)
  require("neo-tree.command").execute({ action = "close", source = "filesystem", position = "left" })
  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(source_tab)
  assert(vim.fn.getcwd() == project, "Note directory changed the code tab's directory")
  assert(vim.api.nvim_get_current_buf() == source and vim.bo[source].modified)
  key("h")
  assert(Obsidian.opts.picker.name == "telescope.nvim")
  assert(not Obsidian.opts.frontmatter.enabled and not Obsidian.opts.ui.enable)
  assert(require("obsidian").VERSION == "3.16.10")

  key("f")
  local picker = picker_with(3)
  local found = paths(picker)
  assert(found[concept] and found[inbox] and found[vault .. "/Home.md"], "Quick switch did not cover the entire vault")
  require("telescope.actions").close(picker.prompt_bufnr)

  key("s")
  picker = picker_with(0)
  picker:reset_prompt("backing")
  assert(vim.wait(5000, function() return picker.manager and paths(picker)[concept] end, 10), "Content search missed the code note")
  require("telescope.actions").close(picker.prompt_bufnr)

  local original_input = vim.fn.input
  vim.fn.input = function() return "测试 随手记" end
  key("n")
  vim.fn.input = original_input
  local note = vim.api.nvim_buf_get_name(0)
  assert(note == vault .. "/00-收件箱/测试-随手记.md", "New note did not use a readable inbox filename: " .. note)
  assert(vim.fn.filereadable(note) == 1 and not read(note):find("---", 1, true), "New note added metadata")

  key("d")
  local daily = vault .. "/01-日记/" .. os.date("%Y-%m-%d") .. ".md"
  assert(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) == daily end, 10), "Daily key used another date or directory")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Today's handwritten record." })
  vim.cmd.write()
  key("d")
  assert(read(daily) == "Today's handwritten record.", "Reopening today's journal changed it")

  vim.cmd.edit(vim.fn.fnameescape(concept))
  key("b")
  picker = picker_with(2)
  found = paths(picker)
  assert(found[inbox] and found[vault .. "/Home.md"], "Backlinks missed Markdown or wiki references")
  require("telescope.actions").close(picker.prompt_bufnr)
  vim.cmd.write()
  assert(read(concept) == original_concept, "Saving rewrote the existing generated block")
  vim.cmd.edit(vim.fn.fnameescape(note))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[go" })
  assert(vim.wait(5000, function()
    return #vim.lsp.get_clients({ name = "obsidian-ls", bufnr = 0 }) == 1
  end, 10), "Note-reference LSP did not attach")
  local completion
  vim.lsp.buf_request(0, "textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(0) }, position = { line = 0, character = 4 },
  }, function(failure, result)
    assert(not failure, vim.inspect(failure))
    completion = result
  end)
  assert(vim.wait(5000, function() return completion ~= nil end, 10), "Note-reference completion did not respond")
  assert(vim.inspect(completion):find("go-slices", 1, true), "Completion missed the existing concept note")
  assert(#notices == 0, table.concat(notices, "\n"))
  print("Pinned Obsidian, cross-project home/tree navigation, Telescope search, inbox/daily notes, backlinks, link completion, and content preservation: OK")
end, debug.traceback)

vim.notify = original_notify
vim.cmd("silent! %bwipeout!")
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
