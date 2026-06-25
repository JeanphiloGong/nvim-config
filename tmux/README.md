# tmux

本目录包含 tmux 模板、AgentBoard 控制面板入口，以及一组辅助脚本。

新服务器最短安装路径：

```sh
~/.config/nvim/tmux/bin/agentboard install
~/.config/nvim/tmux/bin/agentboard doctor
```

启动 tmux 后使用当前 prefix：`Ctrl-a`。

## 常用快捷键

| 快捷键 | 作用 |
| --- | --- |
| `<prefix> + C` | 打开或复用 Neovim `AgentBoard` window。 |
| `<prefix> + M` | 打开 `Agents / Codex / Orch` 菜单。 |
| `<prefix> + J` | 跳回最近一次完成的 Codex pane。 |
| `<prefix> + f` | 右侧分屏并执行 `codex fork <session_or_thread_id>`。 |
| `<prefix> + F` | 下方分屏并执行 `codex fork <session_or_thread_id>`。 |
| `<prefix> + e` | 打开单行 Language Coach 输入。 |
| `<prefix> + E` | 打开带上下文的 Language Coach 输入。 |
| `<prefix> + H` | 打开 Language Coach 历史。 |
| `<prefix> + T` | 设置当前 pane 标签。 |
| `<prefix> + W` | 重命名当前 window。 |
| `<prefix> + G` | 在当前 pane 路径打开 popup shell。 |
| `<prefix> + b` | 复制当前 Git 分支名到剪贴板或 tmux buffer。 |
| `<prefix> + <` | 当前 window 左移。 |
| `<prefix> + >` | 当前 window 右移。 |

## AgentBoard

AgentBoard 是当前 tmux-hosted agents 的 Neovim 控制面板。

打开方式：

```text
<prefix> + C
:AgentBoard
```

AgentBoard 内常用键：

- `j/k` 或 `Ctrl-h/j/k/l`：移动选择。
- `Enter` / `Space`：展开 session 或 window。
- `J`：跳转到选中的 pane。
- `i`：给选中 pane 发送一行输入。
- `O` 或 `0`：给选中 scope 启动一个编排目标。
- `T`：派发下一个 ready task。
- `R`：打开或刷新恢复报告。
- `r`：重新扫描 panes。
- `q`：关闭 AgentBoard window。

AgentBoard 会合并 tmux topology、本地 XDG state 和 Codex hook 信号，用
goal、plan、current、evidence、next、blocked、outcome 这类管理语言展示状态。

详细文档：

- AgentBoard 用法与状态来源：[docs/agent-board.md](docs/agent-board.md)
- 新服务器安装：[docs/agent-board-install.md](docs/agent-board-install.md)
- 管理简报模型：[docs/agent-board-manager-brief.md](docs/agent-board-manager-brief.md)
- session restore：[docs/agent-board-session-restore.md](docs/agent-board-session-restore.md)
- 编排控制台方向：[docs/agent-board-orchestration-console.md](docs/agent-board-orchestration-console.md)
- 产品哲学：[docs/agent-board-product-philosophy.md](docs/agent-board-product-philosophy.md)

## Language Coach

Language Coach 对应 `<prefix> + e`、`<prefix> + E` 和 `<prefix> + H`。

它现在只使用 OpenAI-compatible API，并自动读取：

```sh
~/.config/tmux-language-rewrite/language.env
```

仓库里只放模板：

```sh
tmux/.env.example
```

新机器初始化：

```sh
mkdir -p ~/.config/tmux-language-rewrite
cp ~/.config/nvim/tmux/.env.example ~/.config/tmux-language-rewrite/language.env
chmod 600 ~/.config/tmux-language-rewrite/language.env
```

然后填写 `TMUX_LANG_API_BASE_URL`、`TMUX_LANG_API_KEY` 和
`TMUX_LANG_API_MODEL`。完整说明见 [docs/language-coach.md](docs/language-coach.md)。

## 编排

当前有三层相关能力：

- `tmux-orch`：小型 tmux + jq 状态层，记录 pane/window handoff。
- `tmux-agent-orch`：Mini Kanban 编排试点状态机，负责 task 和 worker。
- `ApiaryDeck`：长期 SDK-first agent orchestration runtime。

建议阅读顺序：

- runtime wrappers 和 skill roles：[docs/orchestration-runtime.md](docs/orchestration-runtime.md)
- tmux-orch 状态层：[docs/tmux-orch.md](docs/tmux-orch.md)
- Mini Kanban pilot：[docs/agent-orch-mini-kanban-pilot.md](docs/agent-orch-mini-kanban-pilot.md)
- ApiaryDeck runtime：[docs/apiarydeck.md](docs/apiarydeck.md)

## Codex 集成

Codex 集成分成两条线：

- AgentBoard lifecycle hooks 把 agent 状态写入本地 XDG state。
- Codex notify 记录完成的 turn，并支持快速跳回。

安装 hook：

```sh
~/.config/nvim/tmux/bin/agentboard install codex
```

详细文档：

- Codex notify 和跳回：[docs/codex-notify.md](docs/codex-notify.md)
- AgentBoard 安装与 hook：[docs/agent-board-install.md](docs/agent-board-install.md)

## 状态栏

当前 tmux 模板使用两行状态栏：

- 第 1 行左侧：`session_name + session_id`
- 第 1 行右侧：`CPU | RAM | time`
- 第 2 行左侧：当前 pane 路径的 Git 分支和 dirty/ahead/behind 标记
- 第 2 行右侧：Codex、Language Coach 和短编排反馈共用的消息槽

如果状态栏闪烁，可以把 `status-interval` 调到 5 或 10 秒。

## 安装与平台说明

- 完整 docs 索引：[docs/README.md](docs/README.md)
- tmux 3.6 源码安装：[docs/tmux-install.md](docs/tmux-install.md)
- Windows / WSL 剪贴板：[docs/windows-wsl-clipboard.md](docs/windows-wsl-clipboard.md)

## 脚本地图

| 脚本 | 作用 |
| --- | --- |
| `bin/agentboard` | install、doctor、scan、open 入口。 |
| `bin/tmux-agent-scan` | 读取 tmux topology 和缓存的 agent state。 |
| `bin/tmux-agent-brief` | 维护 AgentBoard 管理简报。 |
| `bin/tmux-agent-orch` | Mini Kanban 编排状态机。 |
| `bin/apiarydeck` | ApiaryDeck SDK-first runtime helper。 |
| `bin/orch` | tmux-orch Phase A 状态 helper。 |
| `bin/codex-tmux-notify` | Codex notify hook 集成。 |
| `bin/codex-tmux-fork-current` | 把当前 Codex thread fork 到新 pane。 |
| `bin/tmux-language-rewrite` | API-only Language Coach backend。 |

## 验证

修改 tmux helpers 后优先运行：

```sh
tmux/test/tmux-language-rewrite-smoke.sh
tmux/test/apiarydeck-smoke.sh
tmux/test/tmux-agent-orch-smoke.sh
```
