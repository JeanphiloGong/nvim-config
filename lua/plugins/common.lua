-- 通用基础插件：补全、导航、编辑增强
return {
  -- 补全（cmp + LuaSnip）
  {
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
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
        },
      })
    end,
  },

  -- 文件树
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      local function diff_with_gitsigns(base)
        local gs = require("gitsigns")
        local cache = require("gitsigns.cache").cache
        local bufnr = vim.api.nvim_get_current_buf()
        local function try_diff(remaining)
          if cache[bufnr] then
            gs.diffthis(base)
            return
          end
          if remaining <= 0 then
            gs.diffthis(base)
            return
          end
          vim.defer_fn(function()
            try_diff(remaining - 1)
          end, 50)
        end
        try_diff(20)
      end

      require("neo-tree").setup({
        close_if_last_window = true,
        enable_git_status = true,
        enable_diagnostics = true,
        window = {
          position = "left",
          width = 30,
          mappings = {
            ["<space>"] = "toggle_node",
            ["<cr>"] = "open",
            ["P"] = "preview",
            ["s"] = "open_split",
            ["v"] = "open_vsplit",
            ["a"] = "add",
            ["d"] = "delete",
            ["r"] = "rename",
            ["R"] = "refresh",
          },
        },
        filesystem = {
          follow_current_file = { enabled = true },
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = true,
          },
        },
        git_status = {
          window = {
            mappings = {
              ["D"] = "open_and_diff",
              ["H"] = "open_and_diff_head",
            },
          },
          commands = {
            open_and_diff = function(state)
              local commands = require("neo-tree.sources.common.commands")
              commands.open(state)
              vim.schedule(function()
                local tab = vim.api.nvim_get_current_tabpage()
                local cur = vim.api.nvim_get_current_win()
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                  if vim.wo[win].diff then
                    if win == cur then
                      vim.wo[win].diff = false
                    else
                      vim.api.nvim_win_close(win, true)
                    end
                  end
                end
                diff_with_gitsigns()
              end)
            end,
            open_and_diff_head = function(state)
              local commands = require("neo-tree.sources.common.commands")
              commands.open(state)
              vim.schedule(function()
                local tab = vim.api.nvim_get_current_tabpage()
                local cur = vim.api.nvim_get_current_win()
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                  if vim.wo[win].diff then
                    if win == cur then
                      vim.wo[win].diff = false
                    else
                      vim.api.nvim_win_close(win, true)
                    end
                  end
                end
                diff_with_gitsigns("~")
              end)
            end,
          },
        },
        default_component_configs = {
          git_status = {
            symbols = {
              added = "✚",
              modified = "",
              deleted = "✖",
              renamed = "➜",
              untracked = "★",
              ignored = "◌",
            },
          },
        },
      })

    end,
  },

  -- 模糊搜索
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")
      local actions = require("telescope.actions")
      local function select_smart(prompt_bufnr)
        local columns = vim.o.columns
        local lines = vim.o.lines
        if lines > 0 and (columns / lines) >= 2 then
          actions.select_vertical(prompt_bufnr)
        else
          actions.select_horizontal(prompt_bufnr)
        end
      end
      local function lsp_definition_split()
        local params = vim.lsp.util.make_position_params()
        vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result, ctx)
          if err or not result or vim.tbl_isempty(result) then
            return
          end
          local location = result
          if vim.tbl_islist(result) then
            location = result[1]
          end
          local client = ctx and vim.lsp.get_client_by_id(ctx.client_id) or nil
          local encoding = client and client.offset_encoding or "utf-16"
          local win_width = vim.api.nvim_win_get_width(0)
          local win_height = vim.api.nvim_win_get_height(0)
          if win_height > 0 and (win_width / win_height) >= 2 then
            vim.cmd("vsplit")
          else
            vim.cmd("split")
          end
          vim.lsp.util.jump_to_location(location, encoding)
        end)
      end

      telescope.setup({
        defaults = {
          prompt_prefix = "🔍 ",
          selection_caret = "➤ ",
          layout_strategy = "horizontal",
          layout_config = { preview_width = 0.6 },
          mappings = {
            i = {
              ["<leader>s"] = select_smart,
            },
            n = {
              ["<leader>s"] = select_smart,
            },
          },
        },
      })
      pcall(telescope.load_extension, "fzf")

      vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
      vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})

      vim.keymap.set("n", "gd", lsp_definition_split, {})
      vim.keymap.set("n", "gD", builtin.lsp_definitions, {})
      vim.keymap.set("n", "gr", builtin.lsp_references, {})
      vim.keymap.set("n", "gi", builtin.lsp_implementations, {})
    end,
  },

  -- 成对包裹/替换
  {
    "kylechui/nvim-surround",
    event = "InsertEnter",
    config = function()
      require("nvim-surround").setup({
        surrounds = {
          ["t"] = {
            add = function()
              local tag = vim.fn.input("Tag: ")
              return { "<" .. tag .. ">", "</" .. tag .. ">" }
            end,
          },
        },
      })
    end,
  },

  -- tmux 分窗导航
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },

  -- Markdown
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

  -- which-key 提示
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({})
    end,
  },

  -- 行内注释
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("Comment").setup()
    end,
  },

  -- 自动补全括号/引号
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },

  -- 缩进参考线
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "|" },
    },
  },
}
