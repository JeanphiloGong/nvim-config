vim.keymap.set("n", "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Toggle NeoTree" })
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle source=filesystem position=left<cr>", { desc = "NeoTree Files" })
vim.keymap.set("n", "<leader>gs", "<cmd>Neotree toggle source=git_status position=float<cr>", { desc = "NeoTree Git Status" })
vim.keymap.set("n", "<leader>be", "<cmd>Neotree toggle source=buffers position=left<cr>", { desc = "NeoTree Buffers" })

local function copy_path(style)
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("No file name", vim.log.levels.WARN)
    return
  end

  if style == "absolute" then
    path = vim.fn.fnamemodify(path, ":p")
  elseif style == "relative" then
    path = vim.fn.fnamemodify(path, ":.")
  end

  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end

vim.keymap.set("n", "<leader>yp", function()
  copy_path("absolute")
end, { desc = "Yank absolute path" })
vim.keymap.set("n", "<leader>yr", function()
  copy_path("relative")
end, { desc = "Yank relative path" })

-- Markdown 快捷键
vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { desc = "Markdown 预览" })
vim.keymap.set("n", "<leader>mt", "<cmd>GenTocGFM<cr>", { desc = "生成目录 TOC" })
vim.keymap.set("n", "<leader>mu", "<cmd>UpdateToc<cr>", { desc = "更新目录 TOC" })
