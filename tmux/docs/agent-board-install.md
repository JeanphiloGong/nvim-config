# AgentBoard 新服务器安装指南

这份指南用于把当前 `nvim/tmux` 配置部署到另一台 Linux 服务器。目标是能在
tmux 里用 `<prefix> + C` 打开 AgentBoard，并让 Codex hook 把 agent 状态写入
本机状态表。

AgentBoard 本身不需要后台 daemon。它依赖：

- tmux 负责 session/window/pane
- Neovim 负责打开 `:AgentBoard` UI
- Codex hook 负责在 agent 有动作时写入状态
- XDG state 目录保存本机状态

## 依赖

最小依赖：

```sh
tmux
git
nvim
python3
codex
```

推荐依赖：

```sh
jq
node
npm
```

说明：

- `jq` 主要给 `tmux-orch` 相关命令使用，AgentBoard 基础面板不强制依赖它。
- Neovim 建议使用仓库 README 里的版本要求，至少保证 `:AgentBoard` 能加载。
- Codex CLI 需要已经登录，并且新开的 Codex 会话会读取该服务器上的
  `~/.codex/config.toml` 和 `~/.codex/hooks.json`。

## 放置配置

把仓库同步到服务器的标准位置：

```sh
git clone <repo-url> ~/.config/nvim
```

如果服务器上已经有这个目录：

```sh
cd ~/.config/nvim
git pull
```

首次使用 Neovim 配置时，按仓库根 README 的快速开始安装插件：

```sh
nvim
# 在 nvim 里执行：
# :Lazy sync
```

## 启用 tmux 配置

安装 TPM：

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

链接本仓库的 tmux 配置：

```sh
ln -sf ~/.config/nvim/tmux/.tmux.conf ~/.tmux.conf
```

启动或重载 tmux：

```sh
tmux
tmux source ~/.tmux.conf
```

在 tmux 里按：

```text
<prefix> + I
```

安装 tmux 插件。当前配置的 prefix 是 `Ctrl-a`。

## 配置 Codex 状态 hook

AgentBoard 可以扫描 tmux pane，但要获得 Codex 的任务状态、目标、完成摘要和
恢复用 session id，需要配置 Codex hook。

### notify hook

先把 notify 脚本放到固定路径：

```sh
mkdir -p ~/.local/bin
ln -sf "$HOME/.config/nvim/tmux/bin/codex-tmux-notify" ~/.local/bin/codex-tmux-notify
chmod +x ~/.local/bin/codex-tmux-notify
```

编辑 `~/.codex/config.toml`，在全局区域加入：

```toml
notify = ["/home/<you>/.local/bin/codex-tmux-notify"]

[features]
codex_hooks = true
```

注意：

- `/home/<you>` 必须换成服务器上的真实绝对路径。
- `notify = [...]` 不要写进某个 `[projects."..."]` 下面。
- 修改后需要重启 Codex CLI，新启动的 Codex 才会读取配置。

### lifecycle hooks

创建 `~/.codex/hooks.json`：

```sh
mkdir -p ~/.codex
hook="$HOME/.config/nvim/tmux/bin/codex-agent-status-hook"
cat > ~/.codex/hooks.json <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "$hook idle",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$hook working",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$hook working",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$hook working",
            "timeout": 10
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$hook blocked",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$hook done --stop",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF
```

不要直接复制另一台机器的 `~/.codex/auth*.json`、`auth.json` 或 API token。每台
服务器应该独立登录 Codex，或使用自己的凭据管理方式。

## 可选：启用 LLM 简报

默认情况下，AgentBoard 会用本地规则生成管理简报。想要更自然的 Goal / Plan /
Current / Next，可以选择其中一种方式：

使用 Codex CLI：

```sh
export AGENT_BOARD_CODEX_SUMMARY=1
export AGENT_BOARD_CODEX_MODEL=gpt-5.2
export AGENT_BOARD_CODEX_TIMEOUT=45
```

或使用 OpenAI-compatible API：

```sh
export AGENT_BOARD_LLM=1
export OPENAI_API_KEY=...
export AGENT_BOARD_LLM_MODEL=gpt-5.2
```

这些环境变量需要被新启动的 Codex 进程继承。最简单的方式是写到服务器的 shell
启动文件里，然后重新打开 tmux 和 Codex。

## 使用

在 tmux 里：

```text
<prefix> + C  打开 AgentBoard
```

AgentBoard 内常用按键：

```text
j/k 或 Ctrl-h/j/k/l  移动选择
Enter / Space        展开 session/window，或在 pane 上进入预览
i                    给选中 pane 发送一行输入
J                    跳转到选中 pane
R                    打开/刷新恢复报告
r                    重新扫描
q                    关闭
```

恢复报告只在已有 pane 中执行：

```text
codex resume <SESSION_ID>
```

它不会新建 session、window 或 pane。布局恢复仍然交给
`tmux-resurrect` / `tmux-continuum`。

## 验证

检查 tmux 配置是否加载：

```sh
tmux list-keys | grep AgentBoard
```

检查 AgentBoard scanner：

```sh
~/.config/nvim/tmux/bin/tmux-agent-scan --pretty | python3 -m json.tool >/dev/null
```

检查 Neovim 命令是否可加载：

```sh
nvim --headless -u NONE \
  -c "set rtp+=${HOME}/.config/nvim" \
  -c "lua require('agent_board').setup()" \
  -c AgentBoard \
  -c "qa!"
```

检查状态表：

```sh
python3 -m json.tool "${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json"
```

如果文件不存在，先在 tmux 里新开一个 Codex 会话，让它提交一次 prompt 或完成一次
turn。状态写入是事件驱动的，不是定时写入。

## 常见问题

### `<prefix> + C` 没反应

先确认 tmux 配置已经链接并重载：

```sh
readlink ~/.tmux.conf
tmux source ~/.tmux.conf
tmux list-keys | grep agent-board
```

如果仓库不在 `~/.config/nvim`，需要同步调整 `~/.tmux.conf` 里的脚本路径，或把仓库
放回标准位置。

### AgentBoard 只看到 pane，看不到 Codex 状态

通常是 Codex hook 没生效。检查：

```sh
cat ~/.codex/config.toml
cat ~/.codex/hooks.json
```

确认 `codex_hooks = true`、`notify = [...]` 和 hooks 里的命令都指向服务器上的
真实路径。修改后重启 Codex CLI。

### 恢复报告里没有可恢复项

恢复依赖历史状态记录。至少需要有一次 Codex hook 写入过 `codex_session_id`。

检查：

```sh
python3 -m json.tool "${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json" | grep codex_session_id
```

如果没有记录，先在新服务器上启动 Codex 并让它完成一次 turn。

### 另一台服务器的状态没有同步过来

这是预期行为。AgentBoard 状态表保存在服务器本机的 XDG state 目录：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/
```

不要把这个目录当作仓库配置同步。它描述的是该服务器当前 tmux server 和本机 Codex
会话。
