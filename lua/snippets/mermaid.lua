local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

local mermaid = {
  s("mflow", {
    t({
      "flowchart TD",
      "  A[Start] --> B[Process]",
      "  B --> C[End]",
    }),
    i(0),
  }),
  s("mseq", {
    t({
      "sequenceDiagram",
      "  participant U as User",
      "  participant S as Service",
      "  U->>S: request",
      "  S-->>U: response",
    }),
    i(0),
  }),
  s("mstate", {
    t({
      "stateDiagram-v2",
      "  [*] --> Draft",
      "  Draft --> Review: submit",
      "  Review --> Approved: pass",
      "  Review --> Draft: reject",
      "  Approved --> [*]",
    }),
    i(0),
  }),
}

local markdown = {
  s("mflow", {
    t({
      "```mermaid",
      "flowchart TD",
      "  A[Start] --> B[Process]",
      "  B --> C[End]",
      "```",
    }),
    i(0),
  }),
  s("mseq", {
    t({
      "```mermaid",
      "sequenceDiagram",
      "  participant U as User",
      "  participant S as Service",
      "  U->>S: request",
      "  S-->>U: response",
      "```",
    }),
    i(0),
  }),
  s("mstate", {
    t({
      "```mermaid",
      "stateDiagram-v2",
      "  [*] --> Draft",
      "  Draft --> Review: submit",
      "  Review --> Approved: pass",
      "  Review --> Draft: reject",
      "  Approved --> [*]",
      "```",
    }),
    i(0),
  }),
}

return {
  mermaid = mermaid,
  markdown = markdown,
}
