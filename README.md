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
1) 安装依赖：Neovim ≥ 0.11、git、make（编译 telescope-fzf-native）、node + npm/yarn（Prettier、Markdown 预览、Mermaid 工具链）、可选 go（gofmt/gopls）。
2) 将本目录放到 `~/.config/nvim`，首次启动 Neovim 后执行：
   - `:Lazy sync`（安装/编译插件）
   - `:MasonInstall pyright svelte ts_ls`（安装常用 LSP）
   - `:TSUpdate`（安装 Treesitter 解析器）
3) Markdown 预览若自动安装失败，可手动执行 `cd ~/.local/share/nvim/lazy/markdown-preview.nvim/app && npm install`。

### Neovim 安装（Linux 示例）
```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-* /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
```

### Go 安装（Linux 一键复制）
```bash
GO_VERSION=1.22.4
OS=linux
ARCH=amd64

curl -LO https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go${GO_VERSION}.${OS}-${ARCH}.tar.gz
rm -f go${GO_VERSION}.${OS}-${ARCH}.tar.gz

if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi
source ~/.bashrc

go version
```
如果你用的是 zsh，把 `~/.bashrc` 改成 `~/.zshrc` 即可。
架构说明：`uname -m` 为 `x86_64` 用 `ARCH=amd64`，为 `i686/i386` 用 `ARCH=386`。

### 常用 LSP / 工具安装
```bash
# Python
npm install -g pyright

# TypeScript / JavaScript
npm install -g typescript typescript-language-server

# Go
go install golang.org/x/tools/gopls@latest

# Mermaid 语法辅助（推荐）
npm install -g @mermaid-js/mermaid-language-server

# Mermaid 导出工具（可选）
npm install -g @mermaid-js/mermaid-cli
```

## 常用快捷键
- 文件树：`<C-b>` 打开/关闭 Neo-tree。
- 搜索/跳转（Telescope）：`<leader>ff` 文件、`<leader>fg` 全局搜索、`<leader>fb` 缓冲区、`<leader>fh` 帮助；`gd` 智能分屏打开定义（优先均衡分布，必要时再按宽高比兜底）、`gD` 定义列表、`gr` 引用、`gi` 实现；在 Telescope 内用 `<leader>s` 智能分屏打开条目。
- 诊断列表：`<leader>xx` 打开 Trouble 诊断，`<leader>xq` 打开 quickfix。
- 补全：`<Tab>` 确认候选，`<C-Space>` 触发补全。
- Markdown：`<leader>mp` 预览，`<leader>mt` 生成 TOC，`<leader>mu` 更新 TOC。
- Mermaid 导出：在 `.mmd`/`.mermaid` 文件中，`<leader>ms` 导出 SVG，`<leader>mn` 导出 PNG（等价命令 `:MermaidToSvg` / `:MermaidToPng`，后台异步执行）。
- Mermaid 自动导出：保存 `.mmd`/`.mermaid` 后会后台异步执行 `:MermaidToSvg`（需已安装 `mmdc`，不阻塞编辑）。
- Mermaid 片段：在 `markdown` 或 `.mmd` 中输入 `mflow` / `mseq` / `mstate`，然后 `<C-Space>` + `<Tab>` 展开。

## Mermaid 预览（mmd 文件）
1) 在图文件目录启动静态服务（示例）：
```bash
npm install -g live-server
cd docs/flows
live-server
```
2) 浏览器打开同名 `.svg`（例如 `http://127.0.0.1:8080/asset_extract.svg`）。
3) 在 Neovim 编辑 `asset_extract.mmd` 后保存 `:w`，会后台导出并刷新页面；连续快速保存时仅保留最新一次导出任务。

## 插件概览
- 语言/工具链：mason + mason-lspconfig + nvim-lspconfig（pyright、ts_ls、svelte），nvim-cmp + LuaSnip，nvim-treesitter，Prettier。
- 导航/UI：telescope + telescope-fzf-native，neo-tree，which-key。
- Git：gitsigns。
- 编辑效率：Comment.nvim、nvim-surround、nvim-autopairs、trouble.nvim、indent-blankline (ibl)。
- Markdown：vim-markdown、markdown-preview.nvim、vim-markdown-toc。
- Mermaid 语法辅助：`mermaid-language-server`（外部安装）+ LuaSnip 片段（`mflow`/`mseq`/`mstate`）。
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
4) `prefix + C` 打开 nvim `AgentBoard`，用于查看 agent pane 状态并跳转。

## 实用命令
- `:Time` 在光标处插入当前时间戳（YYYY-MM-DD HH:MM:SS）。
- `:AgentBoard` 打开 tmux agent 控制面板。

## 作者
Jeanphilo Gong  
https://github.com/JeanphiloGong

## License
MIT License
