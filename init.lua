-- ~/.config/nvim/init.lua

-- 初始化 lazy.nvim 路径
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 加载插件列表

-- 插件列表
require("lazy").setup({
  -- Mason 插件
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },

  -- 自动适配 mason 的 LSP 安装
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright"},
      })
    end,
  },

  -- Neovim 内建 LSP 支持
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      lspconfig.pyright.setup({ capabilities = capabilities})
    end,
  },
  -- 自动补全系统
{
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",     -- 让 LSP 支持补全
    "L3MON4D3/LuaSnip",         -- 片段引擎
    "saadparwaiz1/cmp_luasnip", -- 片段补全源
  },
  config = function()
    local cmp = require("cmp")
    cmp.setup({
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ['<Tab>'] = cmp.mapping.confirm({ select = true }), -- Tab 选择并确认
        ['<C-Space>'] = cmp.mapping.complete(),              -- 手动触发补全
      }),
      sources = {
        { name = "nvim_lsp" },
        { name = "luasnip" },
      },
    })
  end,
}

})

