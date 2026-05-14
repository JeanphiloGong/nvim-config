# tmux

本目录包含 tmux 模板与辅助脚本。

## Quick Access

- `<prefix> + C`：打开/复用 nvim `AgentBoard` 控制面板
  - 面板会在专用 nvim tab 中全屏打开，底部快捷键提示固定在窗口底部
  - 左侧是可折叠 workspace tree：session -> window -> pane
  - 左侧用 Nerd Font 图标区分 session/window，pane 行左侧显示 agent 图标：`` codex、`󰚩` claude、`` opencode、`` gemini、`` copilot
  - 状态图标固定在左侧 tree column 的右边缘：`` blocked、`` error、`󰔚` stale、`` review-ready、`` working、`` done、`` idle、`` unknown
  - 选中 session/window 时，右侧是 scope inspector：按 attention / review / working / done / quiet 分组，展示每个 agent 的目标、当前动作、阻塞点和结果
  - 选中 pane 时，右侧是单 agent inspector，上方是结构化状态卡片，分开显示 route target / stage / goal / need / outcome，下方是当前 pane 画面，默认每秒自动刷新
  - 在面板里用 `j/k` 或 `Ctrl-h/j/k/l` 移动，`Enter` / `Space` 展开 session/window；在 pane 上进入预览
  - `gw` 展开所有 working agent；`gr` 展开所有 review-ready agent；`gd` 展开所有 done agent
  - `i` 给选中 pane 发送一行输入
  - 预览模式下 `j/k` 或上下键滚动历史，`Esc/q` 返回树
  - `J` 跳转到选中 pane，并保留 `AgentBoard` window 供下次复用
  - `R` 打开/刷新恢复报告；只对 tmux 已经恢复出的已有 pane 提供 `codex resume` 动作，不能恢复的记录写入 XDG state 下的 `agent-board/restore/restore-log.jsonl`
  - `q` 关闭 `AgentBoard` window
  - `r` 重新扫描 pane 列表
  - 鼠标单击选择，双击跳转
- `<prefix> + M`：打开 `Agents / Codex / Orch` 菜单
  - `Agent board`：打开 nvim `AgentBoard`
  - `Orch dashboard`：打开当前 tmux session 的编排状态面板
  - 其余条目：最近完成的 Codex panes，可直接跳回

### AgentBoard 状态来源

`AgentBoard` 用两层信号判断状态：

- Codex lifecycle hooks 主动把健康状态写到当前 tmux pane metadata / pane title：`blocked / error / stale / review-ready / working / done / idle / unknown`
- 同一条记录还会写入工作阶段和管理字段：`phase`、`goal`、`message`、`need`、`outcome`。Codex 当前阶段主要是 `intake / inspecting / editing / testing / committing / waiting / reporting / complete / unknown`
- `tmux-agent-status` 同步维护本地状态表：`${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/panes.json`
- `tmux-agent-brief` 会把 Codex hook 事件追加到 `${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/events/`，并异步生成 `headline`、`plan`、`current`、`evidence`、`next`、`blocked`、`brief_outcome`
  - 默认使用本地规则兜底；设置 `AGENT_BOARD_SUMMARY_CMD` 可调用自定义 summarizer，或设置 `AGENT_BOARD_LLM=1` + `OPENAI_API_KEY` 使用内置 OpenAI-compatible Chat Completions
  - 设置 `AGENT_BOARD_CODEX_SUMMARY=1` 可通过 `agent-board-codex-summary` 调用 `codex exec` 生成 brief；可用 `AGENT_BOARD_CODEX_MODEL`、`AGENT_BOARD_CODEX_TIMEOUT`、`AGENT_BOARD_CODEX_BIN` 调整 Codex 调用
  - 可用 `AGENT_BOARD_LLM_MODEL`、`AGENT_BOARD_LLM_BASE_URL`、`AGENT_BOARD_LLM_TIMEOUT`、`AGENT_BOARD_LLM_MIN_INTERVAL` 调整模型、接口和限频
- `tmux-agent-scan` 只用一次 `tmux list-panes` 读取 topology，并合并本地状态表；不再对每个 pane 高频 `show-option` / `capture-pane`
- AgentBoard 默认每秒刷新右侧当前视图，每 5 秒重新扫描一次 topology / 状态表；可用 `vim.g.agent_board_scan_refresh_ms` 调整扫描间隔
- AgentBoard 管理视图方案见 [docs/agent-board-manager-brief.md](docs/agent-board-manager-brief.md)，右侧优先展示自然语言的目标、计划、当前进展、下一步和阻塞点
- AgentBoard 后续编排控制台方向见 [docs/agent-board-orchestration-console.md](docs/agent-board-orchestration-console.md)，目标是把 development lifecycle skills 变成右侧可操作的 agent 调度语义
- AgentBoard 异常中断后的 agent 会话恢复规格见 [docs/agent-board-session-restore.md](docs/agent-board-session-restore.md)，目标是记录 Codex session id、pane 位置和 cwd，并在 tmux 已恢复出的 pane 中显式执行 `codex resume`

全局 Codex hook 配置在 `~/.codex/hooks.json`，需要 `~/.codex/config.toml`
里的 `[features].codex_hooks = true`。新开的 Codex 会话会读取这份配置。

## Skill Layers

`tmux/skills/` 现在分成三个公开角色和两个内部 helper：

公开角色：

- `$tmux-project-orchestrator-skill`: 项目级协调入口，管理多个 worktree / task windows、项目状态、依赖关系与推进顺序，本身不写代码
- `$tmux-lane-dispatch-skill`: 快速起一个 lane 的轻量入口，只做 preflight + dispatch，不进入完整 task lifecycle
- `$tmux-task-orchestrator-skill`: 单任务窗口的长期操盘角色，负责本地 phase、lane 分配、handoff、review、commit、merge-back 与收尾

内部 helper：

- `$tmux-task-window-bootstrap-skill`: 专门负责新 task 的 worktree + tmux window + fork
- `$tmux-task-lane-bootstrap-skill`: 专门负责 lane 启动、pane_id 注册与 phase-scoped lane 生命周期

默认使用方式：

- 先进入 public role
- 由 public role 再调用内部 helper
- 不要把 internal helper 当成默认的人类入口
- 只有在 public role 明确决定需要新 worktree 或新 lane 时，才加载对应 helper skill

### Runtime Wrappers

先统一解析 helper 根路径，不要在当前项目仓库里搜索 `tmux/bin/*`：

```sh
config_home="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
tmux_bin="$config_home/tmux/bin"
```

现在额外提供三条 orchestration-specific runtime wrapper：

- `$tmux_bin/tmux-orch-preflight`
  - 负责统一的环境/能力检查，不创建 pane、不 fork Codex、不写 tmux-orch 状态
  - 用来判断当前是否能 `dispatch lane`，以及是否具备完整 lifecycle orchestration 能力
- `$tmux_bin/tmux-dispatch-lane`
  - 负责公共 fast-path lane dispatch
  - 只做 preflight 通过后的 lane 启动，不承担 review/commit/merge 生命周期决策
- `$tmux_bin/tmux-task-window-bootstrap`
  - 负责新 task 的 worktree + tmux window + `tmux-orch` 初始注册（可用时）
  - 只负责创建 task window 并分发裸 `codex fork`
  - prompt 由调用方显式执行：`tmux send-keys -t <target> -l "$prompt"` -> `Enter` -> `sleep 0.5` -> `Enter`
- `$tmux_bin/tmux-task-lane-bootstrap`
  - 负责单个 lane pane 的创建、pane 注册、裸 `codex fork`
  - prompt 由调用方显式执行：`tmux send-keys -t <target> -l "$prompt"` -> `Enter` -> `sleep 0.5` -> `Enter`
  - 没有 `jq` 或 `$tmux_bin/orch` 时，继续以 tmux-only degraded mode 工作，不阻塞 lane 创建
- `$tmux_bin/tmux-task-project-handoff`
  - 负责 task window 完成后的确定性 upward handoff
  - 只按 canonical `pane_id` 把 `merge-ready` / `merge-complete` / `blocked` /
    `needs-policy` 交回项目级 orchestrator
- `$tmux_bin/tmux-shared-status`
  - 负责把短状态写到 tmux 第二行共享状态栏
  - 用于“prompt 已发送”“lane 已派发”这类提示，避免回显完整 prompt 正文

这三条 wrapper 是给编排流程用的。
现有 `<prefix> + f` / `<prefix> + F` 仍然保持通用裸 `codex fork <id>`，不自动注入 orchestrator 语义。

重要约束：

- `codex fork` 的第一个参数必须是 Codex 会话/线程 id
  (`CODEX_SESSION_ID` 或 `CODEX_THREAD_ID`，通常表现为 UUID 样式字符串)。
- 不要把 tmux session 名、window 名、pane id 或 worktree 名误当成
  `codex fork` 的 `[SESSION_ID]`。
- 例如 `tender_back/dev-14` 是 tmux session 名，不是可 fork 的 Codex id。

最小示例：

```sh
"$tmux_bin/tmux-dispatch-lane" \
  --task-context "finish the current slice and report back review-ready or blocked"
```

```sh
"$tmux_bin/tmux-task-window-bootstrap" \
  --repo-root "$(git rev-parse --show-toplevel)" \
  --task-kind bugfix \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --task-slug steps-sop-copy
```

```sh
"$tmux_bin/tmux-task-lane-bootstrap" \
  --role coder \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --phase phase1
```

```sh
"$tmux_bin/tmux-task-project-handoff" \
  --status merge-ready \
  --commit "$(git rev-parse --short HEAD)" \
  --refs-line "ISSUE: #41" \
  --note "ready for project-level merge scheduling"
```

## tmux-orch（Phase A 原型）
仓库现在包含一个最小 `tmux-orch` 原型：`$tmux_bin/orch`。

注意：
- `$tmux_bin/orch` 本体仍依赖 `jq`
- `tmux-task-window-bootstrap` / `tmux-task-lane-bootstrap` 在没有 `jq` 时会降级为 tmux-only 模式，不阻塞 pane 创建与 lane dispatch

它的职责很窄：
- tmux 仍负责 live routing
- `pane_id` 仍是机器路由键
- `orch` 只负责持久状态、handoff 日志和廉价 invariant 校验
- `orch handoff` 只会写 durable state，不会主动把 follow-up 指令广播给其他 pane
- 如果另一个 active lane 需要继续工作，orchestrator 必须显式再次发送 prompt
  或 follow-up 消息；不能指望其他 pane 自己读取 `tmux-orch`

这版命令面刻意只覆盖 Phase A：
- `init`
- `register-project`
- `register-window`
- `register-pane`
- `handoff`
- `status`
- `validate`

还没有：
- `phase-start` / `phase-close`
- `retire-pane`
- reviewer 专项校验

### Dashboard

`tmux-orch` 现在提供一个最小 popup dashboard，并挂在现有的
`<prefix> + C` 菜单里。

它展示：
- `orch status`
- 最近 handoffs
- 当前 `validate` 摘要

在 dashboard 里：
- `r`：刷新
- `v`：查看完整 validate 输出
- `q`：关闭
- 自动 pane 创建 / 自动 dispatch

默认状态目录不放在仓库里，而是放到 XDG state 目录：

```sh
${XDG_STATE_HOME:-$HOME/.local/state}/tmux-orch/<session_name>
```

当前 Phase A 默认按 tmux session 分状态根，适合单 task-window 流程。
如果以后要做跨 worktree / 多 task-window 的 project 级编排，再额外引入共享 project root，
而不是现在就把原型做大。

依赖：

```sh
tmux
jq
```

安装 `jq`：

Ubuntu / Debian：
```sh
sudo apt update
sudo apt install -y jq
```

Fedora / RHEL / CentOS：
```sh
sudo dnf install -y jq
# 旧版系统可用 yum：
# sudo yum install -y jq
```

Arch：
```sh
sudo pacman -S jq
```

macOS：
```sh
brew install jq
```

验证：
```sh
jq --version
```

快速入口：

```sh
"$tmux_bin/orch" init
"$tmux_bin/orch" register-project --current-phase phase1
"$tmux_bin/orch" register-window --task "prototype tmux-orch" --phase phase1
"$tmux_bin/orch" register-pane --role orchestrator --scope window
"$tmux_bin/orch" status
"$tmux_bin/orch" validate
```

更完整的用法与边界说明见：
[docs/tmux-orch.md](docs/tmux-orch.md)

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

## 状态栏与快捷操作
当前模板使用两行状态栏：
- 第 1 行左侧：`session_name + session_id`
- 第 1 行右侧：`CPU | RAM | time`
- 第 2 行左侧：当前 pane 路径的 Git 状态（`git:<branch>`，未提交为 `*`，有远端差距时显示 `+ahead/-behind`）
- 第 2 行右侧：共享常驻消息槽（Codex/Language 共用，后触发覆盖前触发）

常用操作：
- `<prefix> + T`：设置当前 pane 标签（显示在 pane 边框）
- `<prefix> + W`：重命名当前 window
- `<prefix> + <`：当前 window 左移一位，并切换到交换后的目标位置
- `<prefix> + >`：当前 window 右移一位，并切换到交换后的目标位置
- `<prefix> + G`：在当前 pane 路径打开 popup shell（用于临时执行 `git status/log/push` 等）
- `<prefix> + b`：复制当前 pane 路径对应仓库的 Git 分支名到剪贴板（至少会写入 tmux buffer）
- `<prefix> + e`：打开一个小 popup 输入一句中文/英文，先用 `trans` 快速生成可粘贴英文并立即复制；如果 Codex 可用，再异步补一版更自然的英文并覆盖剪贴板/状态消息
- `<prefix> + E`：打开可编辑 popup，支持多行输入正文和可选上下文；Codex 会把上下文整理成一行 `CONTEXT` 放在最终 `BEST(codex)` 前面
- `<prefix> + H`：打开 Language Coach 只读历史；支持 `j/k` 翻页、`q` 关闭
- `<prefix> + f`：右侧分屏，在新 pane 执行 `codex fork <session_id>`
- `<prefix> + F`：下方分屏，在新 pane 执行 `codex fork <session_id>`

排查：
- 如果状态栏频繁闪烁，通常是 `status-interval` 太短或 status-right 命令太重：
  - 可以把 `status-interval` 调大（例如 5/10 秒）

Language Coach 依赖（可选）：
- tmux 内默认走双阶段：先同步运行 `trans`，立即写入 `EN` 到状态栏/历史；然后异步启动 `codex exec` 做结构化润色。
- 优先使用 `codex exec` 做结构化语言教练输出；推荐已经登录可用的 Codex CLI。
- Codex 阶段会把 `trans` 的结果作为 first-pass draft 带进 prompt，再生成 `BEST(codex)`、`NOTE`、`TIP`。
- 如果通过 `<prefix> + E` 提供了额外上下文，Codex 还会生成一行整理过的 `CONTEXT`，放在 `BEST(codex)` 前面，帮助理解最终表达该怎么用；`E` 的 popup 支持多行上下文和多行正文。
- 历史里会保留：原句、快速 `EN(trans)`、Codex 的 `NOTE/TIP`、可选的 `CONTEXT`、以及最终推荐的 `BEST(codex)`；`NOTE/TIP/CONTEXT` 会显示在 `EN` 和 `BEST` 之间。
- 提交后状态栏会先显示 `Language: translating...` 或 `Language: translating with context...`，`trans` 返回后更新成 `EN: ...`，Codex 完成后再更新成 `BEST: ...`。
- 剪贴板 / tmux buffer 中只放“推荐使用的更自然英文”，保持原来的粘贴习惯。
- `translate-shell`（命令 `trans`）作为兜底后端；Codex 不可用或失败时会自动回退。
- 可用环境变量：
  - `TMUX_LANG_BACKEND=codex|trans`：仅在你想强制单后端时使用；留空就是默认的“先 `trans`、后 Codex”流程
  - `TMUX_LANG_CODEX_MODEL`（默认 `gpt-5.4-mini`）
  - `TMUX_LANG_CODEX_EFFORT`（默认 `low`）
  - `TMUX_LANG_CODEX_SERVICE_TIER` 暂未开放；默认固定走 `fast`
  - `TMUX_LANG_CODEX_CWD`（默认 `$HOME`）
  - `TMUX_LANG_CODEX_BIN`（可选；显式指定可用的 `codex` 可执行文件）
- 脚本优先使用 `@clipboard`，其次尝试 `pbcopy/wl-copy/xclip/xsel/win32yank.exe/clip.exe`。
- 历史文件默认保存在 `~/.tmux-language-history`（本地文件，不入库）。
- Codex 失败时会把原因写到 `~/.tmux-language.log`；fallback 记录的 `NOTE` 也会带失败原因。
- `<prefix> + H` 会显示历史中的 `IN / EN / NOTE / TIP / CONTEXT / BEST`；支持 `j/k` 翻页、`q` 关闭，旧记录仍可读取。
- 输入提示固定在状态栏第 2 行（`message-line=1`）。

## Codex（可选）：turn 完成提示 + 快速跳回
如果你在 tmux 里运行 Codex CLI，经常会切到别的 pane 做其他事，那么“回到 Codex 输出的 pane”
会有点麻烦。

Codex CLI 支持 `notify` hook：每次 turn 结束会执行一次你配置的命令。这里提供一个 tmux
集成脚本模板：`tmux/bin/codex-tmux-notify`。

效果（推荐：不打断输入）：
- Codex 完成会更新第 2 行左侧常驻消息：`Codex: <session:window> | <summary?>`
  - `<summary?>` 会尽量从 notify 的 JSON 里取最后一条回复的首行（依赖 `python3`，没有也不影响跳转）
- Language 翻译完成也写入同一消息槽，后触发者覆盖前一个结果
- pane 顶部边框会显示三段：`编号 | 你的标签 | Codex 摘要`
- Codex 完成后会把摘要写入当前 pane 的 `@codex_pane_summary`（不再覆盖 pane title）
- 历史条目会记录会话线程 ID（优先使用 `CODEX_THREAD_ID`，否则尝试从 notify JSON 提取）
- Codex 完成后会把 thread id 写到当前 pane 的 `@codex_pane_thread_id`（供 pane 内 fork 优先使用）
- 快速跳回：
  - `<prefix> + J`：跳回“最后一次完成”的 Codex pane
  - `<prefix> + C`：弹出最近完成列表，选择后跳回对应 pane
- 快速 fork：
  - `<prefix> + f` / `<prefix> + F`：从当前 pane 前台进程环境变量读取 `CODEX_SESSION_ID`（没有则回退 `CODEX_THREAD_ID`），并在新分屏里执行 `codex fork <id>`
  - 若当前 pane 未取到，会继续尝试该 pane 的根进程、同 tty 的 `codex` 进程，然后回退当前 pane 的 `@codex_pane_thread_id`
  - 严格模式：不使用全局 `@codex_last_thread_id` 兜底，避免跨 pane 误 fork
  - 注意必须是“环境变量”而不是仅 shell 内变量；并且变量要在当前 pane 对应进程里可见
  - 每次尝试会写日志到 `~/.tmux-codex-fork.log`（可通过 `@codex_fork_log_file` 覆盖，设为 `off` 可关闭）
  - 可用 `tmux show -gv @codex_fork_last_source` / `@codex_fork_last_pid` / `@codex_fork_last_key` 查看最近一次命中来源
  - 可用 `tmux show -pv -t "$TMUX_PANE" @codex_pane_thread_id` 查看当前 pane 记录的 thread id
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
- 更新 `~/.tmux-codex-history`（用于历史列表；同一 thread id 只保留最新一条）

打开历史列表（无额外依赖，使用 tmux 自带 `display-menu`）：
- `<prefix> + C`：弹出最近完成列表，选择某条后跳回对应 pane
  - 列表列顺序：`pane title | thread id(完整) | tmux位置(session:window + path末级) | summary`
  - 列表按“最新在上”显示
  - 条目会附带你设置的 pane 标签（若有）

可选参数（写在 `tmux/.tmux.conf(.wsl)` 里）：
- `set -g @codex_history_limit 12`：列表最多显示多少条（默认 12）
- `set -g @codex_notify_mode off`：不额外弹窗/消息条（推荐，常驻槽模式）
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
