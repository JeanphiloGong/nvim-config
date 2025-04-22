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

### 3.安装对应主题
1.安装starship
```bash
curl -sS https://starship.rs/install.sh | sh
```
2. 然后添加这一行到~/.bashrc
```bash
eval $(starship init bash)
```
3.再执行
source ~/.bashrc

---

## 🧑‍💻 作者

Jeanphilo Gong  
https://github.com/JeanphiloGong

---

## 📄 License

MIT License
```
