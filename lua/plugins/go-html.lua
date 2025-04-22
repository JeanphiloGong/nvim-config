return {
  -- Go plugin (vim-go)
  {
    "fatih/vim-go",
    run = ":GoInstallBinaries",  -- Automatically install Go binaries
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

  -- Other plugins can be added here, without the coc.nvim plugin.
}

