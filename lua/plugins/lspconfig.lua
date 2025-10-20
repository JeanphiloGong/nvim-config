-- ~/.config/nvim/lua/plugins/lspconfig.lua
return {
    -- Specify the nvim-lspconfig plugin
    { 
        "neovim/nvim-lspconfig",
        config = function()
            local lspconfig = require("lspconfig")
            local mason_lspconfig = require("mason-lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- Create handlers for LSP setups
            mason_lspconfig.setup_handlers({
                function(server_name)  -- Default handler for all servers
                    lspconfig[server_name].setup({
                        capabilities = capabilities,
                    })
                end,
                ["svelte"] = function()
                    lspconfig.svelte.setup {
                        capabilities = capabilities, -- Use the same capabilities
                        on_attach = function(client, bufnr)
                            -- Key mappings specific to Svelte language server
                            local opts = { noremap = true, silent = true }
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
                        end,
                    }
                end,
                -- Example for other servers such as Python (Pyright)
                ["pyright"] = function()
                    lspconfig.pyright.setup({
                        capabilities = capabilities,
                    })
                end,
            })
        end,
    },

    -- Treesitter for syntax highlighting for JavaScript, HTML, etc.
    {
        "nvim-treesitter/nvim-treesitter",
        run = ":TSUpdate",  -- Automatically update treesitter parsers
        config = function()
            require("nvim-treesitter.configs").setup {
                ensure_installed = { "javascript", "html", "css", "svelte" },  -- Specify languages to install
                highlight = {
                    enable = true,          -- Enable Treesitter syntax highlighting
                },
            }
        end,
    },
    
    -- Prettier for formatting JavaScript, HTML, and CSS
    {
        "prettier/vim-prettier",
        run = "yarn install --frozen-lockfile --production", -- Adjust this command based on your setup
        ft = { "javascript", "javascriptreact", "typescript", "typescriptreact", "html", "css", "markdown" },  -- File types to apply prettifier
        config = function()
            vim.g.prettier_autoformat = 1  -- Enable auto-formatting on save (optional)
        end,
    },


    { "williamboman/mason.nvim" },  -- Ensure mason is included
    { "williamboman/mason-lspconfig.nvim" },  -- Ensure mason-lspconfig is included
}
