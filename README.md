# 🧠 Neovim Config

我的 Neovim 配置文件，适用于 Python / Go / JavaScript 开发，跨多台设备同步使用。轻量高效，适合终端开发者使用。

## 📦 目录结构

```
~/.config/nvim
├── init.lua         -- 主配置文件
├── lua/             -- 插件和语言服务配置
│   ├── plugins.lua
│   └── lsp.lua
└── ...
```
## 🚀 快速开始（适用于新设备）

### 1. 安装最新版本 Neovim

```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-* /opt/nvim
sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
```

### 2. 安装依赖

```bash
# Node.js 和 npm（用于安装语言服务）
sudo apt install -y nodejs npm

# Python LSP
sudo npm install -g pyright

# TypeScript / JavaScript LSP
sudo npm install -g typescript typescript-language-server

# Go LSP
go install golang.org/x/tools/gopls@latest
```

---

## 🔁 克隆配置

```bash
git@github.com:JeanphiloGong/nvim-config.git
```

---

## 🧩 安装插件

第一次打开 Neovim 后，执行以下命令安装插件：

```vim
:PackerSync
```

或保存 `init.lua` 后自动触发插件安装。

---

## ⚙️ 插件功能（可自定义）

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) - LSP 支持（Python/Go/TS）
- [packer.nvim](https://github.com/wbthomason/packer.nvim) - 插件管理器
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) - 自动补全
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - 模糊搜索
- [treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - 高亮与代码结构分析

---

## 🛠️ 常见问题

### Q: `nvim` 找不到命令？
确保你添加了符号链接：
```bash
sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
```

### Q: 插件没自动安装？
进入 Neovim 后执行：
```vim
:PackerInstall
```

---

## 📚 TODO（计划添加）

- 自动格式化（Black / Prettier / gofmt）
- Git 集成
- Debug 支持（DAP）
- 更丰富的 statusline 和主题配置

---

## 🧑‍💻 作者

Jeanphilo Gong  
https://github.com/JeanphiloGong

---

## 📄 License

MIT License
```
