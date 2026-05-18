# AgentBoard 编排控制台方向

AgentBoard 的右侧可以在后续从管理简报继续发展为 agent 编排控制台。这个方向不改变
tmux 的进程和 pane 管理职责，也不让 UI 直接承担工程判断；它把开发生命周期 skill
作为操作语义，把 tmux pane 作为执行位置，把人类管理者保留为最终调度者。

## 目标

这个方向要解决的问题是：当一个 tmux session 或 window 里有多个 AI agent 时，用户
不应该只看到“谁在 working / done”，还应该能判断下一步应该由哪个 agent 做什么。

AgentBoard 右侧最终应该回答这些问题：

- 当前工作处于哪个开发生命周期阶段？
- 每个 agent 的目标、计划、证据、阻塞点和下一步是什么？
- 哪个 lifecycle skill 最适合下一步？
- 是否应该继续当前 agent、创建新 agent、派 reviewer，还是进入 commit / ship？
- 哪些动作可以从当前界面安全地发给对应 pane？

## 生命周期模型

Development Skill Pack 的七段主流程适合作为编排语义：

```text
workflow-spec
  -> workflow-plan
  -> workflow-build
  -> workflow-test
  -> workflow-simplify
  -> workflow-review
  -> workflow-ship
```

AgentBoard 不需要重新实现这些 skill 的规则。它只需要识别当前工作大致处于哪一段，
并把下一步操作表达成明确的 skill prompt 或 lane dispatch。

支持性 skill 可以作为后续扩展，例如：

- frontend UI 任务建议 `frontend-ui-engineering`
- API 边界任务建议 `api-and-interface-design`
- 复杂 bug 建议 `debugging-and-error-recovery`
- 性能风险建议 `performance-optimization`
- 安全风险建议 `security-and-hardening`
- 文档或 ADR 建议 `documentation-and-adrs`

## 右侧视图

选中单个 agent pane 时，右侧应该保持单 agent 简报，但增加推荐动作：

```text
Goal
Plan
Current Focus
Latest Evidence
Next
Blocked
Outcome

Suggested Skill
Reason
Available Actions
```

示例：

```text
Suggested Skill: workflow-test
Reason: 当前实现已有修改证据，但还没有验证证据。

Actions:
  t  ask this agent to run workflow-test
  r  dispatch reviewer with workflow-review
  c  stage and commit
  J  jump to pane
```

选中 window 或 session 时，右侧应该变成编排控制台：

```text
Workflow Stage: build -> test -> review

Agents:
  codex main:2.1  building Codex summary backend
  codex main:2.2  idle, available for review

Next Coordination Move:
  dispatch workflow-review against the current change

Open Risks:
  - Codex exec summarizer may be slow
  - Goal field can be overwritten by control prompts if hooks regress

Actions:
  n  create new agent lane
  p  send workflow-plan
  b  send workflow-build
  t  send workflow-test
  r  send workflow-review
  s  send workflow-ship
```

## 数据形状

现有 management brief 字段可以继续保留：

```json
{
  "goal": "完成 AgentBoard 编排控制台方向设计",
  "headline": "正在记录后续发展 spec",
  "plan": [
    { "status": "done", "text": "确认方向" },
    { "status": "doing", "text": "记录 spec" },
    { "status": "todo", "text": "后续拆实现任务" }
  ],
  "current": "正在编写未来方向文档",
  "evidence": "已确认 development skill pack 的 lifecycle",
  "next": "进入 workflow-plan 拆任务",
  "blocked": "无",
  "brief_outcome": "方向已记录，尚未进入实现"
}
```

后续可以增加编排字段：

```json
{
  "workflow_stage": "build",
  "suggested_skill": "workflow-test",
  "suggested_reason": "已有实现动作但缺少验证证据",
  "coordination_move": "派 reviewer 执行 workflow-review",
  "actions": [
    {
      "key": "t",
      "label": "send workflow-test",
      "target": "%42",
      "prompt": "$workflow-test\n\nVerify the current change and report evidence."
    }
  ],
  "risks": [
    "Codex exec summarizer may be slow"
  ]
}
```

这些字段应该是 UI 建议，不是自动执行命令。真正发送 prompt、创建 lane 或跳转 pane
仍然需要用户触发。

## 操作边界

AgentBoard 负责：

- 展示 session / window / pane 的工作状态
- 展示 lifecycle stage 和 recommended skill
- 把用户选择的 action 路由到 tmux pane
- 创建或跳转 agent lane
- 记录哪些建议已经发出，避免重复派发

AgentBoard 不负责：

- 直接修改仓库文件
- 代替 skill 判断工程质量
- 在没有用户触发的情况下自动创建 agent
- 自动 commit、ship 或运行高成本 LLM 调用
- 绕过 tmux 直接掌控 agent 进程

## 命令和入口

现有入口保持不变：

```text
prefix + C
:AgentBoard
```

后续 keymap 应该按动作语义分配，而不是按底层实现命名：

- `p`: send `workflow-plan`
- `b`: send `workflow-build`
- `t`: send `workflow-test`
- `r`: send `workflow-review`
- `s`: send `workflow-ship`
- `n`: create a new agent lane
- `J`: jump to selected pane
- `i`: send custom input

破坏性或高成本动作需要确认，例如创建新 agent、commit、ship、调用长耗时总结。

## PlanBoard MVP

第一版先把编排控制台落成 window 级 PlanBoard，而不是全自动调度器。

PlanBoard 的职责是把 `workflow-plan` 输出变成可操作的任务板：

- 当前 tmux window 拥有一个 plan state
- 用户从某个 pane 的 `workflow-plan` 输出导入任务
- AgentBoard 显示任务列表、任务详情、验收项和后续 agent assignment
- 用户仍然决定何时派 worker、tester、simplifier、reviewer 或 ship agent

第一版入口：

- `P`: 打开当前 window 的 PlanBoard
- `I`: 从选中 pane 的 capture history 导入 `workflow-plan` 任务
- `j/k`: 在 PlanBoard 中选择任务
- `b`: 为选中任务派遣 `$workflow-build` agent
- `t`: 为选中任务派遣 `$workflow-test` agent
- `f`: 为选中任务派遣 `$workflow-simplify` agent
- `v`: 为选中任务派遣 `$workflow-review` agent
- `s`: 为选中任务派遣 `$workflow-ship` agent
- `J`: 跳转到选中任务最近绑定的 agent pane
- `Esc`: 返回普通 AgentBoard

派遣动作会复用当前 window 中已有的 Codex session，通过 `tmux-dispatch-lane`
创建新 pane，然后把对应 lifecycle skill prompt 发给新 pane。每次派遣前都需要用户
输入 `yes` 确认。`ship` 只发送 `$workflow-ship` 发布准备 prompt，不自动发布。

Plan state 放在 XDG state 目录：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/agent-board/plans/<window-id>.json
```

这个状态文件不是仓库文件。没有 plan 时，AgentBoard 继续显示原来的 scope /
agent inspector。

第一版 import 只支持稳定的 `workflow-plan` markdown 结构，例如：

```text
## Task 1: Add PlanBoard state

**Description:** ...

**Acceptance criteria:**
- [ ] ...

**Verification:**
- [ ] ...
```

解析失败时保留 raw text，并在 PlanBoard 中显示 import 状态。任意格式计划和 LLM
自动重写不属于 MVP。

## 项目结构

相关实现位置预计仍然在 `tmux/` 节点内：

- `lua/agent_board.lua`: 右侧编排 UI、keymaps、动作选择
- `tmux/bin/tmux-agent-plan`: 读写 window 级 PlanBoard state，并从 pane history 导入 workflow-plan 任务
- `tmux/bin/tmux-dispatch-lane`: 为 PlanBoard 的 build/test/simplify/review/ship 动作创建新 agent lane
- `tmux/bin/tmux-agent-scan`: 读取 tmux topology 和 cached state
- `tmux/bin/tmux-agent-brief`: 生成 management brief 和 recommended action 字段
- `tmux/bin/tmux-task-lane-bootstrap`: 创建新 agent lane 的底层入口
- `tmux/docs/agent-board-manager-brief.md`: 当前管理简报设计
- `tmux/docs/agent-board-orchestration-console.md`: 后续编排控制台方向

## 成功标准

这个方向进入实现阶段前，应该满足这些可检查条件：

- 选中单 pane 时，用户能看到推荐 skill 和推荐原因。
- 选中 window / session 时，用户能看到整体 workflow stage、下一步协调动作和主要风险。
- 用户能从右侧把 lifecycle skill prompt 发送给选中 pane。
- 用户能创建 reviewer / worker lane，但创建前有明确确认。
- UI 建议不会自动执行 destructive action。
- 没有 LLM 或 summarizer 失败时，界面仍可回退到现有 manager brief。
- `J` 跳转、`i` 发送输入、preview 等现有工作流保持可用。

## 风险

- 过度自动化会让 AgentBoard 从“控制台”变成不可预测的自动驾驶系统。
- skill 推荐如果没有证据支撑，会变成新的噪音。
- 右侧动作太多会损害现在的快速观察体验。
- 新 lane 创建如果没有明确目标和退出条件，容易造成 agent 数量膨胀。
- 生命周期阶段可能同时存在，例如一个 window 里有 build agent 和 review agent，不能强行压成一个全局阶段。

## 开放问题

- lifecycle stage 应该按 pane、window 还是 session 计算？
- skill catalog 应该静态内置，还是从 skill root 动态读取？
- action prompt 应该由 UI 模板生成，还是由 summarizer / Codex 生成？
- 创建新 lane 时，是否复用现有 tmux orchestration helpers？
- review / commit / ship 这类高风险动作需要什么确认形式？
- 是否需要记录 action history，避免重复给 agent 发送同一个 skill prompt？

## 相关文档

- [AgentBoard 管理简报](agent-board-manager-brief.md)
- [tmux-orch](tmux-orch.md)
