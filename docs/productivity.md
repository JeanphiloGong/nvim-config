# productivity 插件说明

`lua/plugins/productivity.lua` 提供 Git 侧栏标记与统一的诊断/引用列表，帮助快速浏览改动与错误。


<!-- vim-markdown-toc GFM -->

* [Git 变更标记：gitsigns.nvim](#git-变更标记gitsignsnvim)
* [诊断与列表：trouble.nvim](#诊断与列表troublenvim)
* [常用使用场景](#常用使用场景)

<!-- vim-markdown-toc -->
## Git 变更标记：gitsigns.nvim
- 功能：在行号栏显示新增/修改/删除标记（本配置符号为 `+`, `~`, `_`），支持预览、暂存、撤销等操作。
- 常用命令：
  - `:Gitsigns preview_hunk` 预览当前 hunk。
  - `:Gitsigns stage_hunk`/`reset_hunk` 暂存/撤销当前 hunk。
  - `:Gitsigns next_hunk`/`prev_hunk` 跳转。
  - `:Gitsigns blame_line` 查看当前行 blame。
- 常用快捷键（本仓库配置）：
  - `]c` / `[c`：跳转到下一个/上一个 hunk。
  - `<leader>hs` / `<leader>hr`：暂存/撤销当前 hunk。
  - `<leader>hS` / `<leader>hR`：暂存/撤销当前 buffer。
  - `<leader>hu`：撤销上一次暂存的 hunk。
  - `<leader>hp`：预览当前 hunk。
  - `<leader>hb`：查看当前行 blame。
  - `<leader>tb`：切换当前行 blame 显示。
  - `<leader>hd` / `<leader>hD`：对比当前文件（`hD` 对比 `~`）。
  - `ih`（operator/visual）：选中 hunk（例如 `vih`）。
- 默认在读/新文件事件时自动启用，无需手动配置。

## 诊断与列表：trouble.nvim
- 快捷键：
  - `<leader>xx` 切换诊断列表（包含 LSP/quickfix 诊断）。
  - `<leader>xq` 切换 quickfix 列表。
- 交互：可在列表中 `<cr>` 跳转到具体位置，支持筛选与折叠。
- 适合与 Telescope、LSP 一起使用：例如先用 `gr` 搜索引用，再在 Trouble 中统一浏览。

## 常用使用场景
- 快速浏览改动：用 `]c` / `[c` 在 hunk 间跳转，`<leader>hp` 预览细节。
- 提交前整理：用 `<leader>hs`/`<leader>hr` 精确暂存或撤销小块改动，必要时 `vih` 选中 hunk 再暂存。
- 查看改动来源：`<leader>hb` 或 `<leader>tb` 查看/切换当前行 blame，定位责任提交。
- 快速对比差异：`<leader>hd`/`<leader>hD` 查看当前文件与版本的 diff。
- 集中处理问题：`<leader>xx` 打开诊断列表，逐条跳转修复。
- 快速定位搜索结果：在 quickfix 里汇总查找结果，用 `<leader>xq` 统一浏览。
