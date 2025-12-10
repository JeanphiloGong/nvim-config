# backend 插件说明

`lua/plugins/backend.lua` 负责 LSP 安装与启用，默认覆盖 Python、TypeScript/Svelte 等常见后端/全栈语言。核心逻辑基于 Neovim 0.11 的 `vim.lsp.config`/`vim.lsp.enable` 接口，并与补全插件 `nvim-cmp` 的能力对齐。


<!-- vim-markdown-toc GFM -->

* [包含插件与用途](#包含插件与用途)
* [快速上手](#快速上手)
* [日常使用](#日常使用)
* [扩展与自定义](#扩展与自定义)

<!-- vim-markdown-toc -->
## 包含插件与用途
- `williamboman/mason.nvim`：LSP/DAP/Formatter 安装器，`build = :MasonUpdate` 会在同步时刷新包索引。主命令 `:Mason` 打开 UI 管理安装。
- `williamboman/mason-lspconfig.nvim`：将 Mason 安装结果桥接给 LSP，`ensure_installed = { pyright, svelte, ts_ls }`，`automatic_enable = false` 避免自动 attach，由下方自定义的 `vim.lsp.enable` 负责启用。
- `neovim/nvim-lspconfig`：为各语言启动 LSP，自动注入 `cmp_nvim_lsp` 的补全能力；内置 `with_capabilities` 辅助函数方便在新增服务器时保持一致配置。

## 快速上手
1. 运行 `:Lazy sync` 确保插件就绪。
2. 打开 `:Mason`，确认 `pyright`、`svelte-language-server`、`typescript-language-server` 已安装；若缺少可在 UI 中按 `i` 安装，或执行 `:MasonInstall pyright svelte ts_ls`。
3. 重启/重新打开对应语言的文件，LSP 会根据文件类型自动启动并共享 `nvim-cmp` 的补全能力。

## 日常使用
- Mason 管理：`:Mason` 查看状态，`:MasonInstall <pkg>`/`:MasonUninstall <pkg>` 控制安装，`:MasonLog` 查看日志。
- LSP 状态：`:LspInfo` 查看当前 buffer 的客户端，`:LspStop <name>`/`:LspStart <name>` 手动控制。
- 预设按键：在 Svelte buffer 中提供 `gd` 跳转定义、`K` 悬停、`<leader>rn` 重命名（其他语言可使用 Telescope 全局映射 `gd/gr/gi` 调用 LSP）。
- 诊断与引用：结合 `trouble.nvim`（`<leader>xx`）或 Telescope（`gr` 引用、`gi` 实现）统一查看。

## 扩展与自定义
- 增加新语言：在 `backend.lua` 的 `backend_servers` 或 `frontend_servers` 表中加入 `with_capabilities()` 即可，例如添加 Go：
  ```lua
  local backend_servers = {
    pyright = with_capabilities(),
    gopls = with_capabilities(),
  }
  ```
- 自定义按键：在对应服务器的 `on_attach` 中添加 buffer 映射（参考 Svelte 配置）。
- 若使用外部全局安装的 LSP，也可在 Mason 中关闭/卸载对应包，仅保留 `nvim-lspconfig` 配置即可。
