-- 后端 / LSP 相关插件
return {
  -- Mason 安装器
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },

  -- Mason LSP 配置
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "svelte", "ts_ls", "gopls" },
        automatic_enable = false,
      })
    end,
  },

  -- LSP
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

      local frontend_servers = {
        svelte = with_capabilities({
          on_attach = function(_, bufnr)
            local opts = { noremap = true, silent = true }
            vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
            vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
            vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
          end,
        }),
        ts_ls = with_capabilities(),
      }

      local backend_servers = {
        pyright = with_capabilities(),
        gopls = with_capabilities({
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
              },
              staticcheck = true,
            },
          },
        }),
      }

      local function setup_group(servers)
        for name, opts in pairs(servers) do
          vim.lsp.config(name, opts)
          vim.lsp.enable(name)
        end
      end

      setup_group(frontend_servers)
      setup_group(backend_servers)
    end,
  },

  -- Go 开发增强
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod", "gowork", "gotmpl" },
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        lsp_cfg = false,
        lsp_gofmt = true,
      })
    end,
  },
}
