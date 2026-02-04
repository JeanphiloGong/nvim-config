return {
  -- Git 变更标记与快速暂存
  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
      require("gitsigns").setup({
        signs = { add = { text = "+" }, change = { text = "~" }, delete = { text = "_" } },
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "]c", gs.next_hunk, "Next hunk")
          map("n", "[c", gs.prev_hunk, "Prev hunk")
          map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
          map("v", "<leader>hs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage hunk")
          map("v", "<leader>hr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Reset hunk")
          map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
          map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
          map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>hb", gs.blame_line, "Blame line")
          map("n", "<leader>tb", gs.toggle_current_line_blame, "Toggle line blame")
          map("n", "<leader>hd", gs.diffthis, "Diff this")
          map("n", "<leader>hD", function()
            gs.diffthis("~")
          end, "Diff this ~")
          map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
        end,
      })
    end,
  },

  -- Git 侧边 diff / 历史
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>g1", "<cmd>DiffviewOpen HEAD~1..HEAD<cr>", desc = "Diffview HEAD~1..HEAD" },
      { "<leader>g2", "<cmd>DiffviewOpen HEAD~2..HEAD~1<cr>", desc = "Diffview HEAD~2..HEAD~1" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview History" },
    },
    config = function()
      require("diffview").setup({})
    end,
  },

  -- LazyGit（终端 Git UI）
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },

  -- 统一查看诊断/引用/quickfix
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "Trouble", "TroubleToggle" },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble Diagnostics" },
      { "<leader>xq", "<cmd>Trouble quickfix toggle<cr>", desc = "Trouble Quickfix" },
    },
    config = function()
      require("trouble").setup({})
    end,
  },
}
