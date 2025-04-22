-- ~/.config/nvim/lua/plugins/mason-lspconfig.lua
return {
  "williamboman/mason-lspconfig.nvim",
  config = function()
    -- Ensure necessary LSP servers are installed
    require("mason-lspconfig").setup({
      ensure_installed = {
        "pyright",        -- Python LSP server
        "gopls",          -- Go LSP server
        "html",           -- HTML LSP server (html-languageserver)
      },
      -- Optionally, auto-install LSP servers on startup
      automatic_installation = true,
    })

    -- Configure LSP servers after installation
    local lspconfig = require("lspconfig")

    -- Python LSP (pyright) configuration
    lspconfig.pyright.setup({
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = "openFilesOnly",
          },
        },
      },
    })

    -- Go LSP (gopls) configuration
    lspconfig.gopls.setup({
      cmd = { "gopls" },
      filetypes = { "go", "gomod" },
      root_dir = lspconfig.util.root_pattern("go.mod"),
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,  -- Enable unused parameter analysis
          },
          staticcheck = true,    -- Enable static checks
        },
      },
    })

    -- HTML LSP (html-languageserver) configuration
    lspconfig.html.setup({
      cmd = { "vscode-html-languageserver", "--stdio" },
      filetypes = { "html", "htmldjango" },
      root_dir = lspconfig.util.root_pattern("index.html", "package.json"),
      settings = {
        html = {
          hover = true,        -- Enable hover functionality
          format = {           -- Enable formatting
            enable = true,
          },
        },
      },
    })
  end,
}

