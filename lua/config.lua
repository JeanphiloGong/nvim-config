-- ~/.config/nvim/lua/plugins.lua

return {
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "williamboman/mason.nvim", build = ":MasonUpdate" },
  { "williamboman/mason-lspconfig.nvim" },
  { "neovim/nvim-lspconfig" },

  -- Svelte language server
  { "sveltejs/language-tools" }, 
}

