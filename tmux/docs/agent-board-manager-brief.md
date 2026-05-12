# AgentBoard 管理简报

AgentBoard 应该回答一个管理者查看多个 agent 时最关心的问题：每个
agent 想完成什么、正在按什么计划推进、现在做到哪一步、哪里需要人工介入。

内部路由字段不应该成为主要展示语言。`state=working`、`phase=intake`
和 tmux target id 这些值对实现有用，但它们不能说明 agent 是否真的在推进。

## 目标

AgentBoard 右侧应该从原始状态检查器升级为管理简报。选中单个 pane 时，
右侧展示这个 agent 当前任务的自然语言摘要；选中 window 或 session 时，
右侧聚合同类信息，并按注意力优先级排序。

核心检查标准是：

```text
不跳进 pane，也能看懂这个 agent 在做什么。
```

## 简报内容

每个 agent 的摘要都应该把整体计划作为一等数据：

```text
Goal: 提交当前 AgentBoard 修改

Plan:
  1. done  检查工作区变更
  2. done  确认需要提交的文件
  3. doing 整理 commit message
  4. todo  stage 文件
  5. todo  执行 git commit

Current Focus: 正在整理变更并准备提交
Latest Evidence: 已通过测试，diff 已检查，没有发现额外文件需要处理
Next: stage 文件并提交
Blocked: 无
Outcome: 等待提交完成
```

左侧 tree 保持紧凑，只展示选择 pane 所需的信息：agent 类型、目标位置、
注意力状态和一句短 headline。完整解释放在右侧。

## 状态数据

缓存状态需要把人类可读进度和机器路由信息分开：

```json
{
  "pane_id": "%42",
  "target": "main:2.1",
  "agent": "codex",
  "attention": "working",
  "goal": "提交当前 AgentBoard 修改",
  "headline": "正在整理 commit message",
  "plan": [
    { "status": "done", "text": "检查工作区变更" },
    { "status": "done", "text": "运行可用验证" },
    { "status": "doing", "text": "整理 commit message" },
    { "status": "todo", "text": "stage 文件并提交" }
  ],
  "current": "正在整理 commit message",
  "evidence": "diff 已检查，测试已通过",
  "next": "stage 文件并执行 git commit",
  "blocked": "无",
  "outcome": "等待提交完成",
  "updated_at": "2026-05-12T12:00:00+08:00"
}
```

`attention` 继续作为排序和配色用的紧凑枚举。`goal`、`plan`、`current`、
`evidence`、`next`、`blocked` 和 `outcome` 是给用户看的自然语言字段。
UI 应优先展示这些字段，只在调试视图或次要位置显示 enum 名称。

## 事件流水线

hook 必须保持快速、非阻塞。它只记录事实，然后立即把控制权还给 agent。

```text
Codex hook
  -> 追加一条 per-pane JSONL event
  -> 启动或通知后台 summarizer
  -> 立即返回

background summarizer
  -> 读取最近事件和上一版 summary
  -> 必要时读取一小段 pane snapshot
  -> 生成或修正自然语言简报
  -> 写入 cached pane record

AgentBoard
  -> 读取 cached pane record
  -> 渲染左侧 tree 和右侧管理简报
```

summarizer 不能同步运行在 hook 里。如果 summarizer 调用 LLM，需要设置类似
`AGENT_BOARD_SUMMARIZER=1` 的环境保护，避免它递归触发同一套 lifecycle
hook。

## 事件事实

hook 和轻量扫描器应该记录事实，而不是直接写最终文案：

- 用户输入或推断出的目标
- tool 开始和 tool 结果
- 权限确认或等待输入
- 最终 assistant 回复
- pane 是否存活、tmux topology
- hook payload 不足时可选的一小段屏幕文本

summarizer 负责把这些事实整理成简报。它应该优先使用后台 LLM 生成管理视角，
规则版只作为 LLM 不可用、超时或返回坏 JSON 时的兜底。这样不会打断 agent
自己的执行路径，也不要求每个 agent 主动调用状态上报命令。

## 从 herdr 借鉴什么

herdr 适合作为架构参考，但不是管理简报问题的完整答案。

值得借鉴的是：

- 混合权威模型：runtime topology 判断存活，hook 报告语义状态，屏幕启发式只做兜底
- hook writer 和 UI reader 之间有本地 event/API 边界
- UI 读取缓存状态，避免高频扫描 terminal
- 注意力排序：blocked 高于 review-ready，review-ready 高于 working，working 高于 idle
- “完成但用户未看过”的 done 语义，避免刚完成的 agent 被静默归入 idle

herdr 没有解决的是自然语言规划。它的集成主要上报 `working`、`blocked`、
`idle` 这类紧凑状态；管理简报还需要额外的异步总结层。

## 展示原则

AgentBoard 应该优先展示管理语言，再展示实现语言：

- 右侧展示 `Goal`、`Plan`、`Current Focus`、`Latest Evidence`、`Next`、
  `Blocked` 和 `Outcome`
- `state`、`phase`、raw target id、hook source 只出现在 debug view 或次要弱化文本里
- session/window 视图按 blocked、ready for review、working、done but unseen、quiet 分组
- pane preview 可以保留在简报下方，但不能让原始 terminal 输出成为唯一解释

## 第一版闭环

第一版不需要 daemon 或完整 socket API。当前实现使用一个小的持久化流水线：

1. `codex-agent-status-hook` 继续写原有状态，同时把 hook event 交给 `tmux-agent-brief`
2. `tmux-agent-brief event` 追加到 XDG state 下的 per-pane JSONL 文件
3. `tmux-agent-brief summarize` 在后台读取最近 events、上一版 brief 和规则兜底 brief
4. 如果配置了 `AGENT_BOARD_SUMMARY_CMD`，summarizer 把上下文 JSON 通过 stdin 交给该命令，并要求 stdout 返回 brief JSON
5. 如果设置了 `AGENT_BOARD_LLM=1` 和 `OPENAI_API_KEY`，summarizer 调用 OpenAI-compatible Chat Completions，并要求模型返回 brief JSON
6. 如果 LLM 不可用、超时或返回无效 JSON，summarizer 写入规则兜底 brief
7. 最终 cached summary record 写回 `panes.json`
8. summarizer 加锁，避免同一 pane 同时运行多个后台总结任务
9. AgentBoard 优先渲染 cached brief 字段，再兜底展示 enum 字段
10. pane capture 只作为后续可选输入，不作为 UI 高频操作

配置示例：

```sh
export AGENT_BOARD_LLM=1
export OPENAI_API_KEY=...
export AGENT_BOARD_LLM_MODEL=gpt-5.2
```

使用自定义 summarizer：

```sh
export AGENT_BOARD_SUMMARY_CMD="$HOME/bin/agent-board-summarize"
```

自定义命令的 stdin 是上下文 JSON，stdout 必须是 JSON object，字段为
`attention`、`goal`、`headline`、`plan`、`current`、`evidence`、`next`、
`blocked`、`brief_outcome`。

这样 AgentBoard 才会从 pane 状态列表变成任务管理界面：用户不用跳进每个
agent pane，也能判断谁在推进、谁完成了、谁卡住了，以及下一步该介入哪里。
