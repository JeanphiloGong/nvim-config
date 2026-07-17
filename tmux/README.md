# tmux

本目录包含 tmux 模板、Codex pane 辅助脚本、Language Coach，以及旧
tmux 编排状态 helper。完整 agent 编排和 dashboard 已迁移到独立
ApiaryDeck 项目。

新服务器最短安装路径：

```sh
ln -sf ~/.config/nvim/tmux/.tmux.conf ~/.tmux.conf
tmux source ~/.tmux.conf
```

启动 tmux 后使用当前 prefix：`Ctrl-a`。

## 常用快捷键

| 快捷键 | 作用 |
| --- | --- |
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
- `tmux-agent-orch`：旧 Mini Kanban 编排试点状态机，保留 CLI fallback。
- `ApiaryDeck`：独立 agent orchestration runtime 和 Web dashboard。

建议阅读顺序：

- runtime wrappers 和 skill roles：[docs/orchestration-runtime.md](docs/orchestration-runtime.md)
- tmux-orch 状态层：[docs/tmux-orch.md](docs/tmux-orch.md)
- Mini Kanban pilot：[docs/agent-orch-mini-kanban-pilot.md](docs/agent-orch-mini-kanban-pilot.md)
- ApiaryDeck runtime：独立 ApiaryDeck checkout

## Codex 集成

Codex notify 记录完成的 turn，并支持快速跳回。

安装 hook：

```sh
mkdir -p ~/.local/bin
ln -sf ~/.config/nvim/tmux/bin/codex-tmux-notify ~/.local/bin/codex-tmux-notify
chmod +x ~/.local/bin/codex-tmux-notify
```

详细文档：

- Codex notify 和跳回：[docs/codex-notify.md](docs/codex-notify.md)

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
| `bin/tmux-agent-orch` | Mini Kanban 编排状态机。 |
| `bin/orch` | tmux-orch Phase A 状态 helper。 |
| `bin/codex-tmux-notify` | Codex notify hook 集成。 |
| `bin/codex-tmux-fork-current` | 把当前 Codex thread fork 到新 pane。 |
| `bin/tmux-language-rewrite` | API-only Language Coach backend。 |

## 验证

修改 tmux helpers 后优先运行：

```sh
tmux/test/tmux-language-rewrite-smoke.sh
tmux/test/tmux-agent-orch-smoke.sh
```
