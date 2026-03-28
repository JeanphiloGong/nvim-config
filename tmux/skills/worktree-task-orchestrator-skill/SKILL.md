---
name: worktree-task-orchestrator-skill
description: v0.1.0 - Deprecated compatibility alias for project-window-orchestrator-skill with task-pane-orchestrator-skill as the pane realization layer.
---

# Deprecated Alias

Use `project-window-orchestrator-skill` instead.

The old `worktree-task-orchestrator-skill` name overloaded project/window
coordination and pane realization into one surface.

Canonical replacement:

- `project-window-orchestrator-skill` for project-level coordination across
  task windows and worktrees
- `task-pane-orchestrator-skill` for pane layout, lane startup, and pane-level
  routing inside a specific task window

Migration rule:

- if an older prompt says `worktree-task-orchestrator-skill`, start with
  `project-window-orchestrator-skill`
- use `task-pane-orchestrator-skill` only when a selected task window needs
  pane realization
