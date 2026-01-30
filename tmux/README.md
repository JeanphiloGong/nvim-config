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
