# AGENTS.md (Template)

- Every reply must start with a clear first line (natural language).
- The first line should convey: action + object + stage/result (order is flexible).
- Keep it short; <= 40 chars preferred.

- When to update the first line:
  - When the task object/goal changes, update immediately.
  - When the stage changes (in-progress -> to-verify -> done), update immediately.
  - If blocked, include the reason (e.g. "blocked: <reason>").

- Language selection:
  - 如果用户输入以中文为主，用中文回复。
  - 如果用户输入以英文为主，用英文回复。
  - 混合时跟随用户最后一条消息的主语言，除非用户明确指定。

--- clarity philosophy ---
- Why this matters:
  - The first line is a navigation label. It should let anyone answer:
    "What are we trying to ship?" and "What is happening this turn?" in one glance.
  - Clear labels reduce context switching, prevent duplicated work, and make handoff effortless.
  - Precision beats verbosity: better one accurate sentence than a paragraph of drift.
- Four questions for clarity:
  1) What are you doing? (action)
  2) What does it affect? (object)
  3) What result/goal? (verifiable outcome)
  4) What stage now? (in-progress / to-verify / done / blocked)
- Natural phrasing is preferred; do not force a rigid template.
- Use concrete verbs and objects; avoid vague words like "update stuff".
- If possible, include a verifiable result or next-step signal.

- Object description guidance (recommended):
  - Add a qualifier to the object so it is unambiguous.
  - Preferred qualifiers: scope/module, scenario, affected surface, or key field.
  - Example pattern: <object> + <qualifier> ("tmux 状态栏对齐", "Codex 通知字段", "yank UTF-8 链路")

- Clarify task vs. stage (recommended):
  - Overall task = the final deliverable (feature/fix/refactor/docs), stable across turns.
  - Current stage = what this turn is doing (plan/implement/update/test/verify).
  - Update the overall task only when the deliverable changes; otherwise only update stage.

Examples (general programming):
- 修复登录接口，梳理鉴权流程
- 修复登录接口，实现核心逻辑
- 修复登录接口，补充边界测试
- 修复登录接口，验证回归
- 优化查询性能，分析慢 SQL
- 新增缓存层，设计失效策略
- 排查 CI 失败，定位环境差异
- 补充 API 文档，核对返回字段
