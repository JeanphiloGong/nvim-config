return {
  {
    dir = vim.fn.stdpath("config") .. "/local/code-explain.nvim",
    name = "code-explain.nvim",
    main = "code_explain",
    cmd = { "CodeExplain", "CodeExplainAsk", "CodeExplainHistory", "CodeExplainModel" },
    opts = {},
    keys = {
      { "<leader>ae", ":CodeExplain<cr>", mode = "x", silent = true, desc = "Explain selected code" },
      { "<leader>aa", "<cmd>CodeExplainAsk<cr>", desc = "Ask about code explanation" },
      { "<leader>ah", "<cmd>CodeExplainHistory<cr>", desc = "Code explanation history" },
      { "<leader>am", "<cmd>CodeExplainModel<cr>", desc = "Code explanation model" },
    },
  },
}
