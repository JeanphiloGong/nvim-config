# common 插件说明

`lua/plugins/common.lua` 包含补全、文件导航、模糊搜索、包裹操作、Markdown、快捷键提示等通用功能。下面按功能介绍核心插件与用法。

<!-- vim-markdown-toc GFM -->

* [补全与片段](#补全与片段)
* [文件树](#文件树)
* [搜索与跳转](#搜索与跳转)
* [包裹/编辑增强](#包裹编辑增强)
* [Markdown 工具](#markdown-工具)
* [Tmux 与快捷键提示](#tmux-与快捷键提示)
* [进阶定制](#进阶定制)

<!-- vim-markdown-toc -->
## 补全与片段
- `hrsh7th/nvim-cmp` + `cmp-nvim-lsp` + `LuaSnip` + `cmp_luasnip`
  - 默认按键：`<Tab>` 确认当前候选（可选中第一个），`<C-Space>` 手动触发补全。
  - Snippet 展开由 LuaSnip 接管，可根据需要添加片段文件或调用 `luasnip` API。

## 文件树
- `nvim-neo-tree/neo-tree.nvim`（依赖 `plenary.nvim`、`nvim-web-devicons`、`nui.nvim`）
  - 全局快捷键：`<C-b>` 开/关侧边栏。
  - 侧边栏内置：`<space>` 展开/折叠，`<cr>` 打开，`P` 预览，`s`/`v` 水平/垂直分屏，`a` 新建，`d` 删除，`r` 重命名，`R` 刷新。
  - 跟随当前文件、显示 Git 状态与诊断图标。

## 搜索与跳转
- `nvim-telescope/telescope.nvim` + `telescope-fzf-native.nvim`
  - 快捷键：`<leader>ff` 文件，`<leader>fg` 全局搜索（ripgrep），`<leader>fb` 缓冲区，`<leader>fh` 帮助。
  - LSP 入口：`gd` 定义，`gr` 引用，`gi` 实现（调用 Telescope 内置）。
  - 界面前缀/指示符已定制，安装时会自动编译 fzf-native。

## 包裹/编辑增强
- `kylechui/nvim-surround`：`ys` 添加包裹，`ds` 删除，`cs` 替换；自定义 `t` 包裹会提示输入标签，例如 `ystw` 后输入 `div` 生成 `<div>…</div>`。
- `numToStr/Comment.nvim`：`gc` 系列用于行注释/取消注释（toggle），`gb` 系列用于块注释/取消注释。
  - `gcc`：切换当前行注释状态；`gcip`：切换当前段落；可视模式选中后按 `gc`/`gb` 直接切换选区注释。
  - 按键都是“切换”语义，重复执行即可取消注释；会根据文件类型自动选择正确的注释符。
- `windwp/nvim-autopairs`：自动补全括号/引号，兼容补全插入。
- `lukas-reineke/indent-blankline.nvim`（ibl）：以 `|` 显示缩进参考线。

## Markdown 工具
- `preservim/vim-markdown`：关闭折叠/隐藏，保留原始文本；支持 TOC。
- `mzlogin/vim-markdown-toc`：`<leader>mt` 生成 TOC，`<leader>mu` 更新 TOC。
- `iamcco/markdown-preview.nvim`：构建命令 `cd app && npm install`；快捷键 `<leader>mp` 打开预览（自动关闭 buffer 时退出）。

## Tmux 与快捷键提示
- `christoomey/vim-tmux-navigator`：`Ctrl-h/j/k/l` 在 Neovim 与 tmux 分窗间无缝切换。
- `folke/which-key.nvim`：`<leader>` 起手时弹出可用按键提示，无需手动配置。

## 进阶定制
- 更换补全按键：在 `nvim-cmp` 的 `mapping` 中调整 `<Tab>`/`<C-Space>`。
- 调整文件树行为：修改 `neo-tree` 的 `window.mappings` 或 `filesystem.filtered_items`（例如隐藏 dotfiles）。
- Telescope 默认布局/前缀在 `telescope.setup` 中可修改；新增内置/扩展映射可参考现有 `vim.keymap.set`。
