# frontend 插件说明

`lua/plugins/frontend.lua` 聚焦前端语言的语法高亮、格式化与快速写标签。主要覆盖 Treesitter、Prettier、Emmet。


<!-- vim-markdown-toc GFM -->

* [插件与用途](#插件与用途)
* [快速上手](#快速上手)
* [调优与扩展](#调优与扩展)

<!-- vim-markdown-toc -->
## 插件与用途
- `nvim-treesitter/nvim-treesitter`
  - 安装解析器：`ensure_installed = { javascript, typescript, tsx, html, css, svelte }`，首次同步会执行 `:TSUpdate` 自动下载。
  - 提供语法高亮与解析能力，可配合后续增量选择/折叠等高级功能。
- `prettier/vim-prettier`
  - `run = yarn install --frozen-lockfile --production`，需系统有 Node + npm/yarn。
  - 覆盖文件类型：JS/TS/JSX/TSX/HTML/CSS/Markdown；默认 `vim.g.prettier_autoformat = 1`，保存时自动格式化。
  - 命令：`:Prettier` 手动格式化，`:PrettierAsync` 异步格式化。
- `mattn/emmet-vim`
  - 支持 HTML/CSS/JSX/TSX/Vue/Svelte 等。
  - 领导键：`<C-e>`，模式 `inv`（插入/可视/普通模式均可用）。
  - 常用：在插入模式输入 `div.container>ul>li*3` 按 `<C-e>` 展开结构；可与 `Ctrl-n`/`Ctrl-p` 选择候选。

## 快速上手
1. 运行 `:Lazy sync`，等待 Treesitter/Prettier 安装完成（fzf-native 会自动编译，无需手动干预）。
2. 打开 JS/TS/HTML/CSS/Svelte 文件，确认高亮正常；若解析器缺失可执行 `:TSUpdate` 或 `:TSInstall <lang>`。
3. 保存受支持文件时会自动触发 Prettier；若未生效，检查 `:checkhealth vim-prettier` 或执行 `:Prettier` 观察输出。
4. 在 HTML/JSX/TSX/Svelte 中尝试 Emmet：输入缩写后按 `<C-e>` 展开。

## 调优与扩展
- Treesitter：在 `frontend.lua` 的 `ensure_installed` 中加入需要的语言（如 `vue`、`json`），或开启 `indent`/`incremental_selection` 等模块。
- Prettier：若想改为手动格式化，可将 `vim.g.prettier_autoformat = 0` 写入个人 config；也可通过 `.prettierrc` 自定义格式化规则。
- Emmet：如需调整触发键，修改 `vim.g.user_emmet_leader_key`；若想仅限插入模式，可把 `vim.g.user_emmet_mode` 改为 `"i"`。
