# Work Log Template (Multi-Agent Team)

> Append-only：在实际项目中使用时，`work_log.md` 应只追加条目，不要覆盖或改写他人内容。

## Current Status (Kanban)

> 用途：让人一进仓库就能看到“现在有哪些角色、各自在干什么”。
>
> 协作规则：每个成员只更新自己对应的块，不要改动他人的块。
>
> agent.id：由成员自行设置，但必须全仓库唯一且保持稳定；role 建议参考 `README.md` 的“角色与规范索引”。

```md
## Current Status (Kanban)

### (template) <your-agent-id>
- role: <your-role>
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### human/<name>
- role: 项目负责人 / Tech Lead / 工程经理 / CTO / ...
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### ai/backend/01
- role: 后端工程师
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### ai/frontend/01
- role: 前端工程师
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### ai/architecture/01
- role: 架构师
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### ai/qa-testing/01
- role: 测试工程师
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 

### ai/devops/01
- role: DevOps 工程师
- doing:
  - 
- next:
  - 
- blockers:
  - 
- updated:
  - 
```

## Entry Template (YAML)

```yaml
- timestamp: 2025-12-15T10:30:00+08:00
  agent:
    id: ""
    role: ""
  content:
    objective: ""
    context: ""
    scope:
      in:
        - ""
      out:
        - ""
    plan:
      - ""
    status:
      doing:
        - ""
      next:
        - ""
      done:
        - ""
    decisions:
      - decision: ""
        rationale: ""
        alternatives:
          - ""
    risks:
      - risk: ""
        mitigation: ""
    blockers:
      - ""
    validation:
      - ""
    artifacts:
      - ""
    handoff:
      to: ""
      notes:
        - ""
```
