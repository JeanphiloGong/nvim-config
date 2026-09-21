-- 前端开发相关插件：语法高亮、格式化、Emmet
return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.install({
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "svelte",
        "solidity",
        "c",
        "cpp",
        "rust",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "gotmpl",
      })

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  {
    "prettier/vim-prettier",
    build = "yarn install --frozen-lockfile --production",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact", "html", "css", "markdown" },
    config = function()
      vim.g.prettier_autoformat = 1
    end,
  },

  {
    "mattn/emmet-vim",
    ft = {
      "html",
      "css",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "vue",
      "svelte",
    },
    init = function()
      vim.g.user_emmet_leader_key = "<C-e>"
      vim.g.user_emmet_mode = "inv"
    end,
  },
}
