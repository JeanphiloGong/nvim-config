# AGENTS.md (Template)

- Every reply must start with a clear first line (natural language).
- The first line should convey: action + object + stage/result (order is flexible).
- Keep it short; <= 40 chars preferred.

- When to update the first line:
  - 每一轮都要更新，确保“这一轮在做什么”清晰可见。
  - 如果阶段变化（in-progress -> to-verify -> done），立即更新。
  - 如果阻塞，写清原因（如 "blocked: <reason>"）。

- Language selection:
  - 如果用户输入以中文为主，用中文回复。
  - 如果用户输入以英文为主，用英文回复。
  - 混合时跟随用户最后一条消息的主语言，除非用户明确指定。

--- clarity philosophy ---
- Why this matters:
  - 第一行是“这一轮的导航标签”，让人一眼知道：这一轮在做什么。
  - 清晰标签降低切换成本，减少重复沟通与返工。
  - 精准胜过冗长：一句话说清本轮动作即可。
- Four questions for clarity:
  1) What are you doing this turn? (action)
  2) What does it affect? (object)
  3) What result/next step this turn? (verifiable outcome)
  4) What stage now? (in-progress / to-verify / done / blocked)
- Natural phrasing is preferred; do not force a rigid template.
- Use concrete verbs and objects; avoid vague words like "update stuff".
- If possible, include a verifiable result or next-step signal.
- Focus on “this turn”; avoid describing the overall project goal.

- Object description guidance (recommended):
  - Add a qualifier to the object so it is unambiguous.
  - Preferred qualifiers: scope/module, scenario, affected surface, or key field.
  - Example pattern: <object> + <qualifier> ("tmux 状态栏对齐", "Codex 通知字段", "yank UTF-8 链路")

Examples (general programming):
- 梳理登录鉴权流程，进行中
- 更新配置参数，待验证
- 修复分屏逻辑，验证回归
- 排查 CI 失败，定位环境差异
- 补充 API 文档，核对返回字段
