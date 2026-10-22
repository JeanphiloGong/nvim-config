-- Run with: nvim --headless '+luafile test/treesitter-smoke.lua'
local ok, err = pcall(function()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Injection test", "", "```python", "print(1)", "```",
    "", "```javascript", "const answer = 42;", "```",
  })
  vim.bo[buf].filetype = "markdown"
  local parser = vim.treesitter.get_parser(buf, "markdown")
  parser:parse(true)
  local children = parser:children()
  assert(children.python, "Python code fence was not parsed")
  assert(children.javascript, "JavaScript code fence was not parsed")
  assert(vim.treesitter.highlighter.active[buf], "Markdown highlighting is inactive")
  vim.api.nvim_buf_set_lines(buf, 3, 4, false, { "print(2)" })
  local done, parse_error = false, nil
  parser:parse(true, function(e)
    parse_error, done = e, true
  end)
  assert(vim.wait(5000, function() return done end), "Async parse timed out")
  assert(not parse_error, tostring(parse_error))
  print("Treesitter Markdown injections and async edit: OK")

  local go_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(go_buf)
  vim.api.nvim_buf_set_lines(go_buf, 0, -1, false, {
    "package main", "func main() {", "  value := 1", "  println(value)", "}",
  })
  vim.bo[go_buf].filetype = "go"
  vim.treesitter.get_parser(go_buf, "go"):parse(true)
  vim.api.nvim_win_set_cursor(0, { 4, 10 })
  assert(require("go.ts.go").in_func(), "Go function lookup failed")
  assert(#require("guihua.ts_utils").collect_local_matches(go_buf) > 0, "Go locals lookup failed")
  assert(vim.treesitter.highlighter.active[go_buf], "Go highlighting is inactive")
  assert(vim.bo[go_buf].indentexpr == "v:lua.require'nvim-treesitter'.indentexpr()", "Go indentexpr is missing")
  assert(type(require("nvim-treesitter").indentexpr()) == "number", "Go indentation failed")
  print("Go and guihua Treesitter integration: OK")

  for _, lang in ipairs({
    "markdown", "markdown_inline", "python", "javascript", "typescript", "tsx",
    "html", "css", "svelte", "solidity", "c", "cpp", "rust",
    "go", "gomod", "gosum", "gowork", "gotmpl",
  }) do
    assert(vim.treesitter.language.add(lang), "Missing parser: " .. lang)
    assert(vim.treesitter.query.get(lang, "highlights"), "Missing highlight query: " .. lang)
  end
  print("All configured parser libraries and highlight queries: OK")
end)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
