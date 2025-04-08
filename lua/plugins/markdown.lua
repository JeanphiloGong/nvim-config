return {
  {
    "preservim/vim-markdown",
    ft = { "markdown" },
    config = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_conceal = 0
      vim.g.vim_markdown_toc_autofit = 1
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    ft = { "markdown" },
    config = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_theme = "dark"
    end,
  },
  {
    "mzlogin/vim-markdown-toc",
    ft = { "markdown" },
  },
}

