-- ~/.config/nvim/lua/plugins/telescope.lua

return {
  'nvim-telescope/telescope.nvim',
  branch = 'master',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }, -- 提升模糊匹配性能
  },
  config = function()
    local telescope = require('telescope')
    local builtin = require('telescope.builtin')

    telescope.setup{
      defaults = {
        prompt_prefix = "🔍 ",
        selection_caret = "➤ ",
        layout_strategy = 'horizontal',
        layout_config = { preview_width = 0.6 },
      },
    }
    pcall(telescope.load_extension, 'fzf') -- 如果编译成功则启用 fzf 加速

    -- 基础映射
    vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

    -- LSP 整合
    vim.keymap.set('n', 'gd', builtin.lsp_definitions, {})
    vim.keymap.set('n', 'gr', builtin.lsp_references, {})
    vim.keymap.set('n', 'gi', builtin.lsp_implementations, {})
  end
}
