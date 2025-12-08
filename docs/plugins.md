# 插件与使用速览

面向新手的开箱指南：安装依赖后，运行 `:Lazy sync`、`:MasonInstall pyright svelte ts_ls`、`:TSUpdate` 即可启用主要功能。

## 准备工作
- 确保 Neovim 版本 ≥ 0.11，并安装 `git`、`make`（用于 telescope-fzf-native）、`node + npm/yarn`（用于 Prettier、Markdown 预览）。
- 打开 Neovim 后执行：
  - `:Lazy sync` 同步插件（fzf-native 会自动编译）。
  - `:MasonInstall pyright svelte ts_ls` 安装常用 LSP。
  - `:TSUpdate` 安装/更新 Treesitter 解析器。

## 导航 / 搜索
- Telescope（含 fzf-native 加速）：`<leader>ff` 文件、`<leader>fg` 全局搜索、`<leader>fb` 缓冲区、`<leader>fh` 帮助；`gd` 定义、`gr` 引用、`gi` 实现。
- Neo-tree 文件树：`<C-b>` 打开/关闭，内置新增/重命名/删除/分屏等常用操作。

## LSP / 补全 / 语法
- Mason + nvim-lspconfig：预配置 `pyright`、`ts_ls`（TypeScript）、`svelte`，执行 `:Mason` 可管理安装；`svelte` 缓冲区提供 `gd`/`K`/`<leader>rn` 便捷键。
- nvim-cmp + LuaSnip：`<Tab>` 确认补全，`<C-Space>` 手动触发补全，内置 snippet 支持。
- Treesitter：为 JavaScript/TypeScript/TSX/HTML/CSS/Svelte 提供高亮与解析。
- Prettier：对 JS/TS/HTML/CSS/Markdown 自动格式化（保存时生效）。

## Git
- gitsigns：侧边栏显示变更标记、行内 blame，可用 `:Gitsigns preview_hunk|stage_hunk|reset_hunk` 等命令快速操作。

## 编辑效率
- Comment.nvim：`gc` 行注释，`gbc` 块注释。
- nvim-surround：`ys` 增加包裹，`ds` 删除，`cs` 替换。
- nvim-autopairs：自动补全括号/引号。
- which-key：提示 `<leader>` 起手的可用快捷键。
- trouble.nvim：`<leader>xx` 打开诊断列表，`<leader>xq` 打开 quickfix。
- indent-blankline (ibl)：显示缩进参考线，便于阅读嵌套代码。

## Markdown
- vim-markdown + vim-markdown-toc：`<leader>mt` 生成 TOC，`<leader>mu` 更新 TOC。
- markdown-preview.nvim：`<leader>mp` 开启预览。

## Tmux
- vim-tmux-navigator：默认 `Ctrl-h/j/k/l` 在 Neovim 与 tmux 分窗间无缝移动。

## 缩进策略
- 2 空格：JavaScript/TypeScript/JSX/TSX/Svelte/HTML/Markdown。
- 4 空格：C/C++/Rust/Python。
- Go：tab 宽度 4，不转空格（配合 gofmt）。
- 其他文件：沿用全局 4 空格、expandtab 设置。

## 其他
- `:Time` 命令可在光标处插入当前时间戳（格式：YYYY-MM-DD HH:MM:SS）。
