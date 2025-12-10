# productivity 插件说明

`lua/plugins/productivity.lua` 提供 Git 侧栏标记与统一的诊断/引用列表，帮助快速浏览改动与错误。


<!-- vim-markdown-toc GFM -->

* [Git 变更标记：gitsigns.nvim](#git-变更标记gitsignsnvim)
* [诊断与列表：trouble.nvim](#诊断与列表troublenvim)

<!-- vim-markdown-toc -->
## Git 变更标记：gitsigns.nvim
- 功能：在行号栏显示新增/修改/删除标记（本配置符号为 `+`, `~`, `_`），支持预览、暂存、撤销等操作。
- 常用命令：
  - `:Gitsigns preview_hunk` 预览当前 hunk。
  - `:Gitsigns stage_hunk`/`reset_hunk` 暂存/撤销当前 hunk。
  - `:Gitsigns next_hunk`/`prev_hunk` 跳转。
  - `:Gitsigns blame_line` 查看当前行 blame。
- 默认在读/新文件事件时自动启用，无需手动配置。

## 诊断与列表：trouble.nvim
- 快捷键：
  - `<leader>xx` 切换诊断列表（包含 LSP/quickfix 诊断）。
  - `<leader>xq` 切换 quickfix 列表。
- 交互：可在列表中 `<cr>` 跳转到具体位置，支持筛选与折叠。
- 适合与 Telescope、LSP 一起使用：例如先用 `gr` 搜索引用，再在 Trouble 中统一浏览。
