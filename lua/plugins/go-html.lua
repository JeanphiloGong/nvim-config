-- lua/plugins/go-html.lua
return {
  -- Go plugin (vim-go)
  {
    "fatih/vim-go",
    run = ":GoInstallBinaries",
    config = function()
      -- Configure vim-go
      vim.g.go_fmt_command = "goimports"
      vim.g.go_auto_type_info = 1

      -- Set up gopls (LSP)
      vim.g.go_def_mapping_enabled = 0
      vim.g.go_info_mode = "gopls"
      vim.cmd("autocmd FileType go setlocal omnifunc=vim.lsp.omnifunc")  -- Enable LSP autocomplete
    end,
  },

  -- Coc.nvim for autocompletion (HTML, CSS, JavaScript, etc.)
  {
    "neoclide/coc.nvim", branch = "release",
    config = function()
      vim.cmd("CocInstall coc-html")  -- Install HTML autocompletion
    end,
  },
}

