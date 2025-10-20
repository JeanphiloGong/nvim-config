-- ~/.config/nvim/lua/plugins/mason-lspconfig.lua
return {
  "williamboman/mason-lspconfig.nvim",
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = { "pyright", "svelte" },
    })
  end,
}

