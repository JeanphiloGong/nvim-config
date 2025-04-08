vim.keymap.set("n", "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Toggle NeoTree" })

-- Markdown 快捷键
vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { desc = "Markdown 预览" })
vim.keymap.set("n", "<leader>mt", "<cmd>GenTocGFM<cr>", { desc = "生成目录 TOC" })
vim.keymap.set("n", "<leader>mu", "<cmd>UpdateToc<cr>", { desc = "更新目录 TOC" })

