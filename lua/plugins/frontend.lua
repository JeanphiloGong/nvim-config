-- 前端开发相关插件：语法高亮、格式化、Emmet
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local languages = {
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "svelte",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "gotmpl",
      }

      local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
      if ok_configs then
        configs.setup({
          ensure_installed = languages,
          highlight = { enable = true },
        })
        return
      end

      local ok_ts, ts = pcall(require, "nvim-treesitter")
      if not ok_ts then
        return
      end
      ts.setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })
      pcall(ts.install, languages)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  {
    "prettier/vim-prettier",
    run = "yarn install --frozen-lockfile --production",
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
