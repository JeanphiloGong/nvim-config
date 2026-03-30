# tmux

本目录包含 tmux 模板与辅助脚本。

## Quick Access

- `<prefix> + C`：打开 `Codex / Orch` 菜单
  - `Orch dashboard`：打开当前 tmux session 的编排状态面板
  - 其余条目：最近完成的 Codex panes，可直接跳回

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

现在额外提供三条 orchestration-specific runtime wrapper：

- `tmux/bin/tmux-orch-preflight`
  - 负责统一的环境/能力检查，不创建 pane、不 fork Codex、不写 tmux-orch 状态
  - 用来判断当前是否能 `dispatch lane`，以及是否具备完整 lifecycle orchestration 能力
- `tmux/bin/tmux-dispatch-lane`
  - 负责公共 fast-path lane dispatch
  - 只做 preflight 通过后的 lane 启动，不承担 review/commit/merge 生命周期决策
- `tmux/bin/tmux-task-window-bootstrap`
  - 负责新 task 的 worktree + tmux window + `tmux-orch` 初始注册（可用时）
  - 先执行裸 `codex fork`，确认子 pane 进入 Codex 后再发送 orchestrator startup prompt
- `tmux/bin/tmux-task-lane-bootstrap`
  - 负责单个 lane pane 的创建、pane 注册、role prompt 注入
  - 先执行裸 `codex fork`，确认子 pane 进入 Codex 后再发送 lane startup prompt
  - 没有 `jq` 或 `tmux/bin/orch` 时，继续以 tmux-only degraded mode 工作，不阻塞 lane 创建
- `tmux/bin/tmux-task-project-handoff`
  - 负责 task window 完成后的确定性 upward handoff
  - 只按 canonical `pane_id` 把 `merge-ready` / `merge-complete` / `blocked` /
    `needs-policy` 交回项目级 orchestrator

这三条 wrapper 是给编排流程用的。
现有 `<prefix> + f` / `<prefix> + F` 仍然保持通用裸 `codex fork <id>`，不自动注入 orchestrator 语义。

最小示例：

```sh
tmux/bin/tmux-dispatch-lane \
  --task-context "finish the current slice and report back review-ready or blocked"
```

```sh
tmux/bin/tmux-task-window-bootstrap \
  --repo-root "$(git rev-parse --show-toplevel)" \
  --task-kind bugfix \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --task-slug steps-sop-copy
```

```sh
tmux/bin/tmux-task-lane-bootstrap \
  --role coder \
  --task-context "make the Steps and SOP purpose difference obvious" \
  --phase phase1
```

```sh
tmux/bin/tmux-task-project-handoff \
  --status merge-ready \
  --commit "$(git rev-parse --short HEAD)" \
  --refs-line "ISSUE: #41" \
  --note "ready for project-level merge scheduling"
```

## tmux-orch（Phase A 原型）
仓库现在包含一个最小 `tmux-orch` 原型：`tmux/bin/orch`。

注意：
- `tmux/bin/orch` 本体仍依赖 `jq`
- `tmux-task-window-bootstrap` / `tmux-task-lane-bootstrap` 在没有 `jq` 时会降级为 tmux-only 模式，不阻塞 pane 创建与 lane dispatch

它的职责很窄：
- tmux 仍负责 live routing
- `pane_id` 仍是机器路由键
- `orch` 只负责持久状态、handoff 日志和廉价 invariant 校验

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
tmux/bin/orch init
tmux/bin/orch register-project --current-phase phase1
tmux/bin/orch register-window --task "prototype tmux-orch" --phase phase1
tmux/bin/orch register-pane --role orchestrator --scope window
tmux/bin/orch status
tmux/bin/orch validate
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
- `<prefix> + g`：在底部输入一句中文/英文，后台生成地道英文并复制到剪贴板（可用时），完成后更新第 2 行左侧常驻消息槽
- `<prefix> + H`：打开 Language Coach 只读历史（最近记录）
- `<prefix> + f`：右侧分屏，在新 pane 执行 `codex fork <session_id>`
- `<prefix> + F`：下方分屏，在新 pane 执行 `codex fork <session_id>`

排查：
- 如果状态栏频繁闪烁，通常是 `status-interval` 太短或 status-right 命令太重：
  - 可以把 `status-interval` 调大（例如 5/10 秒）

Language Coach 依赖（可选）：
- 推荐安装 `translate-shell`（命令 `trans`），否则脚本会退化为原文输出。
- 脚本优先使用 `@clipboard`，其次尝试 `pbcopy/wl-copy/xclip/xsel/win32yank.exe/clip.exe`。
- 历史文件默认保存在 `~/.tmux-language-history`（本地文件，不入库）。
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
