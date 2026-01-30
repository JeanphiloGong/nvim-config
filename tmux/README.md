# tmux (WSL / Windows 剪贴板)

这份说明用于解决 Windows Terminal + WSL + tmux + tmux-yank 组合下的中文复制乱码问题。

## 问题原因（简版）
- tmux-yank 默认会用 `clip.exe` 把内容送到 Windows 剪贴板。
- `clip.exe` 对 UTF-8 不友好，中文很容易乱码。

## 需要安装的工具
- `win32yank.exe`（必须）：负责把 UTF-8 文本正确写入 Windows 剪贴板。

## 安装 win32yank（Windows 侧）
1) 下载：
```
https://github.com/equalsraf/win32yank/releases
```
2) 解压得到 `win32yank.exe`。
3) 放到 Windows PATH 里（推荐两种方式之一）：
- 放到 `C:\Windows\System32\`
- 或放到任意目录，并把该目录加入系统 PATH

## 验证 win32yank 是否可用
在 Windows PowerShell 里执行：
```
win32yank.exe -i --crlf
```
- 看到用法提示或命令等待输入，说明已可用。
- 注意：`win32yank.exe` 没有 `--version` 参数。

在 WSL 里验证：
```
which win32yank.exe
```
期望输出类似：
```
/mnt/c/Windows/System32/win32yank.exe
```

快速测试剪贴板链路（WSL 内执行）：
```
echo "中文测试 ABC 123" | win32yank.exe -i --crlf
```
然后在 Windows 中粘贴，若中文正常即可。

## tmux 配置要点（避免被 clip.exe 覆盖）
关键原则：tmux-yank 会在启动时绑定 `y`，必须禁用它的默认绑定并在 TPM 之后手动绑定。

推荐在 `tmux/.tmux.conf.wsl` 中保持以下配置：
```
# 禁止 tmux-yank 绑定 y
set -g @yank_key 'None'

# 指定 Windows 剪贴板工具
set -g @clipboard 'win32yank.exe -i --crlf'
set -g @yank_selection 'clipboard'

# 在 TPM 之后强制覆盖 y（复制但不退出 copy-mode）
unbind-key -T copy-mode-vi y
unbind-key -T copy-mode y
bind-key -T copy-mode-vi y send -X copy-pipe "win32yank.exe -i --crlf"
bind-key -T copy-mode y     send -X copy-pipe "win32yank.exe -i --crlf"
```

## 常用排查命令
查看当前 `y` 实际绑定：
```
tmux list-keys -T copy-mode-vi | grep ' y '
```
正常应看到 `win32yank.exe`，不应出现 `clip.exe`。

## 注意事项
- `tmux-yank` 版本可能在启动时重绑 `y`，所以自定义绑定必须放在 `run '~/.tmux/plugins/tpm/tpm'` 之后。
- 如果不方便重启 tmux server，可在当前会话里手动执行 unbind/bind 覆盖。

## Focus（状态栏常驻“最重要的事”）
本仓库的 tmux 模板提供一个很常见的工作流：
- 状态栏左侧常驻显示 “Focus”（显示的是 `@focus`，编辑后会从文件首行同步）。
- 需要改动时按快捷键弹出 popup（或 fallback 到新 window）编辑。

约定文件：
- `~/.tmux-focus.md`
  - 第 1 行：状态栏展示（尽量短）
  - 后续行：随便写细节/清单/链接

使用方式：
- 查看：看 tmux 状态栏左侧的 `FOCUS: ...`
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

效果：
- turn 完成时弹出一条 tmux “toast” 提示（默认用 popup，更像系统通知）：`Codex done: <session:window> | <summary?>`
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
2) 应出现 `Codex done ...` 的 popup/message 提示（会自动消失）。
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
- `set -g @codex_notify_mode popup`：用 popup 弹窗提示（推荐；不支持时自动降级为 message）
- `set -g @codex_notify_mode message`：用 tmux 消息条提示
- `set -g @codex_notify_mode off`：关闭提示（只保留跳回能力）
- `set -g @codex_popup_corner br`：popup 位置：`tr/br/tl/bl`（右上/右下/左上/左下）
- `set -g @codex_popup_width 60`：popup 宽度（字符数）
- `set -g @codex_popup_height 6`：popup 高度（字符数）
- `set -g @codex_popup_duration 2`：popup 停留秒数

排查：
- 如果你“跳不回去”，最常见原因是你在不同 tmux server（例如用了不同的 `tmux -L <name>`）。
  - 同一个 tmux server 里的不同 session 是可以跳转的（本模板会先 `switch-client` 再切 window/pane）。
