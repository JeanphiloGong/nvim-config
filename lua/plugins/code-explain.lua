local function wiki_directory()
  return vim.fn.expand(vim.g.learning_wiki_vault or "~/Documents/Learning Wiki")
end

return {
  {
    dir = vim.fn.stdpath("config") .. "/local/code-explain.nvim",
    name = "code-explain.nvim",
    main = "code_explain",
    cmd = { "CodeExplain", "CodeExplainAsk", "CodeExplainHistory", "CodeExplainModel" },
    opts = {},
    init = function()
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("LearningWiki", { clear = true }),
        pattern = "CodeExplainComplete",
        callback = function(event)
          if vim.g.learning_wiki_enabled == false then return end
          local ok = pcall(vim.system, {
            "python3", vim.fn.stdpath("config") .. "/tools/learning-wiki/wiki.py", "--vault", wiki_directory(),
          }, { stdin = vim.json.encode(event.data), text = true }, function(result)
            if result.code ~= 0 then
              vim.schedule(function()
                vim.notify("Learning Wiki update failed; explanation saved. "
                  .. ((result.stderr or ""):match("[^\n]+") or "Check Python 3.11+ and the provider configuration."),
                  vim.log.levels.WARN)
              end)
            end
          end)
          if not ok then
            vim.notify("Could not start Learning Wiki; explanation saved. Check Python 3.11+ on PATH.", vim.log.levels.WARN)
          end
        end,
      })
      vim.api.nvim_create_user_command("LearningWikiOpen", function()
        local index = wiki_directory() .. "/Learning.md"
        if vim.fn.filereadable(index) == 0 then
          vim.notify("The Learning Wiki is not ready yet. After an explanation, allow its background update to finish.", vim.log.levels.INFO)
          return
        end
        vim.cmd.tabnew(vim.fn.fnameescape(index))
      end, { desc = "Open the learning Wiki" })
    end,
    keys = {
      { "<leader>ae", ":CodeExplain<cr>", mode = "x", silent = true, desc = "Explain selected code" },
      { "<leader>aa", "<cmd>CodeExplainAsk<cr>", desc = "Ask about code explanation" },
      { "<leader>ah", "<cmd>CodeExplainHistory<cr>", desc = "Code explanation history" },
      { "<leader>am", "<cmd>CodeExplainModel<cr>", desc = "Code explanation model" },
      { "<leader>aw", "<cmd>LearningWikiOpen<cr>", desc = "Open learning Wiki" },
    },
  },
}
