# Neovim 配置

轻量、面向全栈的 Neovim 配置，涵盖前端（TS/JS/Svelte/HTML/CSS）、后端（Python/Go 等）、Markdown 与 tmux 工作流。

## 目录结构
```
~/.config/nvim
├── init.lua                # 主入口
├── lua/
│   ├── keymaps.lua         # 快捷键
│   └── plugins/            # 插件拆分配置
├── docs/
│   └── plugins.md          # 插件与使用速览（新手首选）
├── tmux/.tmux.conf         # tmux 配置
└── test/                   # TypeScript 缩进示例
```

## 快速开始
1) 安装依赖：Neovim ≥ 0.11、git、make（编译 telescope-fzf-native）、node + npm/yarn（Prettier 与 Markdown 预览）、可选 go（gofmt/gopls）。
2) 将本目录放到 `~/.config/nvim`，首次启动 Neovim 后执行：
   - `:Lazy sync`（安装/编译插件）
   - `:MasonInstall pyright svelte ts_ls`（安装常用 LSP）
   - `:TSUpdate`（安装 Treesitter 解析器）
3) Markdown 预览若自动安装失败，可手动执行 `cd ~/.local/share/nvim/lazy/markdown-preview.nvim/app && npm install`。

## 常用快捷键
- 文件树：`<C-b>` 打开/关闭 Neo-tree。
- 搜索/跳转（Telescope）：`<leader>ff` 文件、`<leader>fg` 全局搜索、`<leader>fb` 缓冲区、`<leader>fh` 帮助；`gd` 定义、`gr` 引用、`gi` 实现。
- 诊断列表：`<leader>xx` 打开 Trouble 诊断，`<leader>xq` 打开 quickfix。
- 补全：`<Tab>` 确认候选，`<C-Space>` 触发补全。
- Markdown：`<leader>mp` 预览，`<leader>mt` 生成 TOC，`<leader>mu` 更新 TOC。

## 插件概览
- 语言/工具链：mason + mason-lspconfig + nvim-lspconfig（pyright、ts_ls、svelte），nvim-cmp + LuaSnip，nvim-treesitter，Prettier。
- 导航/UI：telescope + telescope-fzf-native，neo-tree，which-key。
- Git：gitsigns。
- 编辑效率：Comment.nvim、nvim-surround、nvim-autopairs、trouble.nvim、indent-blankline (ibl)。
- Markdown：vim-markdown、markdown-preview.nvim、vim-markdown-toc。
- 终端/分窗：vim-tmux-navigator。
- 更多细节与用法请见 `docs/plugins.md`。

## 缩进策略
- 2 空格：JS/TS/JSX/TSX/Svelte/HTML/Markdown。
- 4 空格：C/C++/Rust/Python；其他默认 4 空格。
- Go：tab 宽度 4，不转空格（配合 gofmt）。

## 终端主题（可选）
使用 starship：
```bash
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init bash)"' >> ~/.bashrc
source ~/.bashrc
```

## tmux 使用
1) 安装 TPM：`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
2) 关联配置：`ln -sf ~/.config/nvim/tmux/.tmux.conf ~/.tmux.conf`
3) 启动 tmux 后执行 `tmux source ~/.tmux.conf`，再按 `prefix + I` 安装插件。

## 实用命令
- `:Time` 在光标处插入当前时间戳（YYYY-MM-DD HH:MM:SS）。

## 作者
Jeanphilo Gong  
https://github.com/JeanphiloGong

## License
MIT License
