-- 前端开发相关插件：语法高亮、格式化、Emmet
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
      if not ok_configs then
        return
      end

      configs.setup({
        ensure_installed = {
          "javascript",
          "typescript",
          "tsx",
          "html",
          "css",
          "svelte",
          "c",
          "cpp",
          "rust",
          "go",
          "gomod",
          "gosum",
          "gowork",
          "gotmpl",
        },
        auto_install = true,
        highlight = { enable = true },
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
