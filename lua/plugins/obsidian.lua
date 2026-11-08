return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "v3.16.10",
    ft = "markdown",
    cmd = "Obsidian",
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = function()
      local vault = vim.fn.expand("~/Documents/Obsidian Vault")
      vim.fn.mkdir(vault, "p")
      return {
        legacy_commands = false,
        workspaces = { { name = "personal", path = vault } },
        picker = { name = "telescope.nvim" },
        notes_subdir = "00-收件箱",
        new_notes_location = "notes_subdir",
        daily_notes = { folder = "01-日记", date_format = "YYYY-MM-DD" },
        backlinks = { parse_headers = false },
        note_id_func = require("obsidian.builtin").title_id,
        note = { template = vim.NIL },
        frontmatter = { enabled = false },
        ui = { enable = false },
      }
    end,
    keys = {
      { "<leader>nf", "<cmd>Obsidian quick_switch<cr>", desc = "Find notes" },
      { "<leader>ns", "<cmd>Obsidian search<cr>", desc = "Search note contents" },
      { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "New inbox note" },
      { "<leader>nd", "<cmd>Obsidian today<cr>", desc = "Today's daily note" },
      { "<leader>nb", "<cmd>Obsidian backlinks<cr>", desc = "Note backlinks" },
      {
        "<leader>ne",
        function()
          vim.cmd.tabnew()
          require("neo-tree.command").execute({
            source = "filesystem",
            position = "left",
            dir = tostring(Obsidian.dir),
            reveal = false,
          })
        end,
        desc = "Personal notes directory",
      },
      {
        "<leader>nh",
        function()
          vim.cmd.tabnew(vim.fn.fnameescape(tostring(Obsidian.dir / "Home.md")))
          vim.cmd.tcd(vim.fn.fnameescape(tostring(Obsidian.dir)))
        end,
        desc = "Personal notes home",
      },
    },
  },
}
