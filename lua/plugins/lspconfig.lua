-- ~/.config/nvim/lua/plugins/lspconfig.lua
return {
    -- Specify the nvim-lspconfig plugin
{
    "neovim/nvim-lspconfig",
    config = function()
        local lspconfig = vim.lsp.config
        local mason_lspconfig = require("mason-lspconfig")
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        -- 检查 mason-lspconfig 是否存在 setup_handlers 函数
        if mason_lspconfig.setup_handlers then
            -- ✅ 新版本 mason-lspconfig 的用法
            mason_lspconfig.setup_handlers({
                -- 默认处理所有 LSP server
                function(server_name)
                    lspconfig(server_name, {
                        capabilities = capabilities,
                    })
                end,
                -- 单独配置 Svelte
                ["svelte"] = function()
                    lspconfig("svelte", {
                        capabilities = capabilities,
                        on_attach = function(_, bufnr)
                            local opts = { noremap = true, silent = true }
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
                            vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
                        end,
                    })
                end,

                -- Pyright 示例
                ["pyright"] = function()
                    lspconfig("pyright", {
                        capabilities = capabilities,
                    })
                end,
            })
        else
            -- ⚙️ 兼容旧版 mason-lspconfig（没有 setup_handlers）
            for _, server in ipairs(mason_lspconfig.get_installed_servers()) do
                lspconfig(server, {
                    capabilities = capabilities,
                })
            end
        end
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
