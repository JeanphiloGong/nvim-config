# lazygit 安装与使用（WSL）

`lazygit` 是一个终端 Git UI 工具。本仓库已配置 `<leader>gg` 打开 LazyGit，
但需要先在系统里安装 `lazygit` 可执行文件。

## 方案 A：Go 安装（推荐）
```bash
go install github.com/jesseduffield/lazygit@latest
```

如果提示 `lazygit: command not found`，说明 `GOPATH/bin` 不在 PATH：
```bash
export PATH="$PATH:$(go env GOPATH)/bin"
```

可持久化到：
- `~/.bashrc` 或
- `~/.local/bin/env`（本仓库常用）

## 方案 B：手动下载二进制
适合没有 Go 或想固定版本时使用：
```bash
# 示例（请按需替换版本号）
curl -Lo /tmp/lazygit.tar.gz \
  "https://github.com/jesseduffield/lazygit/releases/download/v0.58.1/lazygit_0.58.1_Linux_x86_64.tar.gz"
tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit -D -t /usr/local/bin/
```

## 方案 C：apt（若仓库可用）
```bash
sudo apt install lazygit
```
如果提示找不到包，请改用方案 A/B。

## 验证
```bash
lazygit --version
```

## Neovim 使用
本仓库已绑定：
- `<leader>gg` 打开 LazyGit

若在 Nvim 中仍提示找不到命令，请重启 Nvim 以刷新 PATH。
