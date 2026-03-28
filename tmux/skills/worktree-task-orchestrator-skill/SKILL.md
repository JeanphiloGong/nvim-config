---
name: worktree-task-orchestrator-skill
description: v0.1.12 - Deprecated compatibility alias; use task-window-orchestrator-skill for task-window coordination and task-pane-orchestrator-skill for pane realization.
---

# Deprecated Alias

The old `worktree-task-orchestrator-skill` name overloaded two different
responsibilities:

- task-window coordination
- pane and lane realization

Use the split skills instead:

- `task-window-orchestrator-skill` for one task window's phase, status, and
  lane plan
- `task-pane-orchestrator-skill` for pane layout, lane startup, and pane_id
  routing

Migration rule:

- if an older prompt says `worktree-task-orchestrator-skill`, start with
  `task-window-orchestrator-skill`
- let the task-window layer call `task-pane-orchestrator-skill` when pane
  changes are actually needed
