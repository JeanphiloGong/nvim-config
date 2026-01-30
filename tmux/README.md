# tmux

本目录包含 tmux 模板与辅助脚本。

## 安装 tmux 3.6（Linux 源码编译）
适用于大多数 Linux 发行版（需要编译工具链 + libevent + ncurses）。

1) 安装依赖

Ubuntu / Debian：
```sh
sudo apt update
sudo apt install -y build-essential pkg-config libevent-dev libncurses-dev bison
```

Fedora / RHEL / CentOS：
```sh
sudo dnf install -y gcc make pkgconf-pkg-config libevent-devel ncurses-devel bison
# 旧版系统可用 yum：
# sudo yum install -y gcc make pkgconfig libevent-devel ncurses-devel bison
```

Arch：
```sh
sudo pacman -S --needed base-devel pkgconf libevent ncurses bison
```

2) 下载与编译安装
```sh
wget https://github.com/tmux/tmux/releases/download/3.6/tmux-3.6.tar.gz
tar -xzf tmux-3.6.tar.gz
cd tmux-3.6
./configure
make
sudo make install
```

3) 验证
```sh
tmux -V
which tmux
```
期望输出 `tmux 3.6`，路径通常是 `/usr/local/bin/tmux`。

可选：无 sudo 时可用自定义前缀：
```sh
./configure --prefix=$HOME/local
make
make install
```
并确保 `$HOME/local/bin` 在 PATH 中。

## Windows / WSL 剪贴板（tmux-yank）
Windows Terminal + WSL 的中文复制问题与配置要点见：
[docs/windows-wsl-clipboard.md](docs/windows-wsl-clipboard.md)

## Focus（状态栏常驻“最重要的事”）
本仓库的 tmux 模板提供一个很常见的工作流：
- 状态栏第 2 行右侧常驻显示 “Focus”（显示的是 `@focus`，编辑后会从文件首行同步）。
- 需要改动时按快捷键弹出 popup（或 fallback 到新 window）编辑。

约定文件：
- `~/.tmux-focus.md`
  - 第 1 行：状态栏展示（尽量短）
  - 后续行：随便写细节/清单/链接

使用方式：
- 查看：看 tmux 状态栏第 2 行右侧的 `Focus: ...`
- 编辑：`<prefix> + f`
  - tmux 支持 `display-popup` 时会用 popup 打开编辑器
  - 不支持时会新开一个名为 `Focus` 的 window

排查：
- 如果按 `<prefix> + f` 打开的不是 `~/.tmux-focus.md`，先检查它是否被误创建成“目录/软链接”：
  - `ls -ld ~/.tmux-focus.md`
- 如果状态栏频繁闪烁，通常是 `status-interval` 太短或 status-right 命令太重：
  - 可以把 `status-interval` 调大（例如 5/10 秒）

## Codex（可选）：turn 完成提示 + 快速跳回
如果你在 tmux 里运行 Codex CLI，经常会切到别的 pane 做其他事，那么“回到 Codex 输出的 pane”
会有点麻烦。

Codex CLI 支持 `notify` hook：每次 turn 结束会执行一次你配置的命令。这里提供一个 tmux
集成脚本模板：`tmux/bin/codex-tmux-notify`。

效果（推荐：不打断输入）：
- 状态栏第 2 行常驻显示最近一次完成信息：`Codex: <session:window> | <summary?>`
  - `<summary?>` 会尽量从 notify 的 JSON 里取最后一条回复的首行（依赖 `python3`，没有也不影响跳转）
- 快速跳回：
  - `<prefix> + J`：跳回“最后一次完成”的 Codex pane
  - `<prefix> + C`：弹出最近完成列表，选择后跳回（同时跑多个 Codex 也能用）
- 跳回后如何快速“返回原处”（tmux 内置）：
  - 如果是跨 session 跳转：`<prefix> + L` 回到上一个 session（等价 `tmux switch-client -l`）
  - 如果只是同一 window 里切 pane：`<prefix> + ;` 回到上一个 pane（last-pane）

### 1) 安装/放置脚本（本机一次性）
建议把脚本放到 `~/.local/bin`（或任何在 PATH 里的目录）：
```sh
mkdir -p ~/.local/bin
# 如果你就在本仓库根目录执行（~/.config/nvim），可以用 $PWD：
# ln -sf "$PWD/tmux/bin/codex-tmux-notify" ~/.local/bin/codex-tmux-notify
#
# 更通用的写法（本仓库默认安装在 ~/.config/nvim）：
ln -sf "$HOME/.config/nvim/tmux/bin/codex-tmux-notify" ~/.local/bin/codex-tmux-notify
chmod +x ~/.local/bin/codex-tmux-notify
```

### 2) 配置 Codex notify（本机一次性）
编辑 `~/.codex/config.toml`，加入（路径请写绝对路径）：
```toml
notify = ["/home/<you>/.local/bin/codex-tmux-notify"]
```
注意：
- `notify = [...]` 必须写在 `config.toml` 的“全局区域”（第一个 `[projects."..."]` 之前），不要写进某个 `[projects]` 里。
- TOML 不支持 `~` / `$HOME` 展开，所以这里必须写绝对路径。
- 修改 `~/.codex/config.toml` 后，需要重启一次 Codex CLI（新启动的 codex 才会读取新配置）。

### 3) 验证
1) 在 tmux 里运行 Codex，等它完成一次 turn。
2) 状态栏第 2 行应更新为最新的 `Codex: ...`（并写入历史文件）。
3) 用 `<prefix> + J` 跳回最后一次完成的位置。
4) 用 `<prefix> + C` 打开列表，选择后跳回。

### 4) 多个 Codex 同时完成怎么办？
notify 每次触发都会：
- 更新 `@codex_last_win/@codex_last_pane`（用于“一键跳回最后一个”）
- 追加一条到 `~/.tmux-codex-history`（用于历史列表）

打开历史列表（无额外依赖，使用 tmux 自带 `display-menu`）：
- `<prefix> + C`：弹出最近完成列表，选择后跳回对应 pane
  - 列表按“最新在上”显示

可选参数（写在 `tmux/.tmux.conf(.wsl)` 里）：
- `set -g @codex_history_limit 12`：列表最多显示多少条（默认 12）
- `set -g @codex_notify_mode off`：不弹窗/不消息条（推荐，配合第 2 行状态栏即可）
- `set -g @codex_notify_mode message`：额外用 tmux 消息条提示（非模态）
- `set -g @codex_notify_mode popup`：额外用 popup 弹窗提示（模态：会捕获按键并暂停 pane 刷新）
- `set -g @codex_popup_corner br`：popup 位置：`tr/br/tl/bl`（右上/右下/左上/左下）
- `set -g @codex_popup_margin 1`：popup 距离窗口边缘的留白（默认 1）
- `set -g @codex_popup_width 60`：popup 宽度（字符数）
- `set -g @codex_popup_height 6`：popup 高度（字符数）
- `set -g @codex_popup_duration 2`：popup 停留秒数

排查：
- 如果你“跳不回去”，最常见原因是你在不同 tmux server（例如用了不同的 `tmux -L <name>`）。
  - 同一个 tmux server 里的不同 session 是可以跳转的（本模板会先 `switch-client` 再切 window/pane）。
