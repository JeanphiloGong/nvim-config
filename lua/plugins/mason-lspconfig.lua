-- ~/.config/nvim/lua/plugins/mason-lspconfig.lua
return {
  "williamboman/mason-lspconfig.nvim",
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = { "pyright", "svelte", "ts_ls" },
      automatic_enable = false, -- we call vim.lsp.enable after setting capabilities
    })
  end,
}
