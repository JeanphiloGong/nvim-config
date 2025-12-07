-- ~/.config/nvim/lua/plugins/lspconfig.lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local function with_capabilities(opts)
        opts = opts or {}
        opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})
        return opts
      end

      -- Configure servers before enabling them
      vim.lsp.config("svelte", with_capabilities({
        on_attach = function(_, bufnr)
          local opts = { noremap = true, silent = true }
          vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
          vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
          vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
        end,
      }))

      for _, server in ipairs({ "pyright", "ts_ls" }) do
        vim.lsp.config(server, with_capabilities())
      end

      for _, server in ipairs({ "pyright", "svelte", "ts_ls" }) do
        vim.lsp.enable(server)
      end
    end,
  },

  -- Treesitter for syntax highlighting for JavaScript, TypeScript, HTML, etc.
  {
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "javascript", "typescript", "tsx", "html", "css", "svelte" },
        highlight = {
          enable = true,
        },
      })
    end,
  },

  -- Prettier for formatting JavaScript, HTML, and CSS
  {
    "prettier/vim-prettier",
    run = "yarn install --frozen-lockfile --production",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact", "html", "css", "markdown" },
    config = function()
      vim.g.prettier_autoformat = 1
    end,
  },

  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
}
