return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local cmp = require("cmp")

    cmp.setup({
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)  -- Using LuaSnip for snippets
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()  -- Select the next item in the completion list
          else
            fallback()  -- If no completion is visible, fallback to default Tab behavior
          end
        end, { "i", "s" }),

        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()  -- Select the previous item in the completion list
          else
            fallback()  -- Fallback if no completion is visible
          end
        end, { "i", "s" }),

        ["<C-Space>"] = cmp.mapping.complete(),  -- Trigger completion manually with Ctrl-Space
        ["<CR>"] = cmp.mapping.confirm({ select = true }),  -- Confirm completion with Enter
      }),

      sources = {
        { name = "nvim_lsp" },  -- LSP source
        { name = "luasnip" },    -- Snippet source
      },
    })
  end,
}

