# frontend 插件说明

`lua/plugins/frontend.lua` 聚焦前端语言的语法高亮、格式化与快速写标签。主要覆盖 Treesitter、Prettier、Emmet。


<!-- vim-markdown-toc GFM -->

* [插件与用途](#插件与用途)
* [快速上手](#快速上手)
* [调优与扩展](#调优与扩展)

<!-- vim-markdown-toc -->
## 插件与用途
- `nvim-treesitter/nvim-treesitter`
  - 使用支持 Neovim 0.12+ 的 `main` 分支，通过 `require("nvim-treesitter").install(...)` 异步安装 Markdown、Python、前端和后端语言解析器；不再加载旧版 `configs` 接口。
  - 编译解析器需要 `tree-sitter` CLI >= 0.26.1、C 编译器、curl 和 tar。可通过 `cargo install tree-sitter-cli --locked` 安装 CLI，并确保其所在目录已加入 PATH。
  - Markdown fenced code block 会按代码块标注的语言注入对应 parser；标注为 `python` 的代码块需要 Python parser。
  - 当前 `main` 分支不提供 `tmux` parser；tmux 配置文件使用 Neovim 自带的语法高亮。
- `prettier/vim-prettier`
  - `build = yarn install --frozen-lockfile --production`，需系统有 Node + npm/yarn。
  - 覆盖文件类型：JS/TS/JSX/TSX/HTML/CSS/Markdown；默认 `vim.g.prettier_autoformat = 1`，保存时自动格式化。
  - 命令：`:Prettier` 手动格式化，`:PrettierAsync` 异步格式化。
- `mattn/emmet-vim`
  - 支持 HTML/CSS/JSX/TSX/Vue/Svelte 等。
  - 领导键：`<C-e>`，模式 `inv`（插入/可视/普通模式均可用）。
  - 常用：在插入模式输入 `div.container>ul>li*3` 按 `<C-e>` 展开结构；可与 `Ctrl-n`/`Ctrl-p` 选择候选。

## 快速上手
1. 运行 `:Lazy sync`，等待 Treesitter/Prettier 安装完成（fzf-native 会自动编译，无需手动干预）。
2. 打开 Markdown、Python、JS/TS/HTML/CSS/Svelte 文件，确认高亮正常；若解析器缺失可执行 `:TSInstall <lang>`，使用 `:TSUpdate` 更新已有解析器。首次异步安装完成后重新打开文件，以启用高亮和缩进；从旧分支迁移后需保存并重启 Neovim。
3. 保存受支持文件时会自动触发 Prettier；若未生效，检查 `:checkhealth vim-prettier` 或执行 `:Prettier` 观察输出。
4. 在 HTML/JSX/TSX/Svelte 中尝试 Emmet：输入缩写后按 `<C-e>` 展开。

## 调优与扩展
- Treesitter：在 `frontend.lua` 的 parser 列表中加入需要的语言（如 `vue`、`json`）；FileType 事件为已安装解析器的文件调用 `vim.treesitter.start()`，并设置新版 Treesitter 的 `indentexpr()`。
- 回归检查：在仓库根目录执行 `nvim --headless '+luafile test/treesitter-smoke.lua'`，检查 Markdown 代码块注入、异步编辑解析、Go/guihua 集成，以及全部配置语言的解析器和高亮查询。
- Prettier：若想改为手动格式化，可将 `vim.g.prettier_autoformat = 0` 写入个人 config；也可通过 `.prettierrc` 自定义格式化规则。
- Emmet：如需调整触发键，修改 `vim.g.user_emmet_leader_key`；若想仅限插入模式，可把 `vim.g.user_emmet_mode` 改为 `"i"`。
