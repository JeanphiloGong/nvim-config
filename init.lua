vim.g.mapleader = " "
-- ~/.config/nvim/init.lua

-- 初始化 lazy.nvim 插件管理器路径
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

-- 加载快捷键配置（你已写在 lua/keymaps.lua）
require("keymaps")

-- 加载 plugins 目录下的所有插件模块
require("lazy").setup("plugins")


-- init.lua 配置（如果你用的是 Lua 配置）
vim.opt.number = true         -- 显示绝对行号（当前行）
vim.opt.relativenumber = true -- 其它行显示相对行号
-- Set tab size (number of spaces per tab)
vim.opt.tabstop = 4      -- Number of spaces when pressing <Tab>
vim.opt.softtabstop = 4  -- Number of spaces for insert mode <Tab>
vim.opt.shiftwidth = 4    -- Number of spaces for automatic indentation
vim.opt.expandtab = true  -- Use spaces instead of tabs
-- auto-indentation
vim.opt.autoindent = true
vim.opt.smartindent = true

-- 自动优化 Markdown 编辑体验
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

-- 设置加入时间戳方便记录
vim.api.nvim_create_user_command('Time', function()
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	vim.api.nvim_put({ timestamp }, 'l', true, true)
end, {})

-- 设置加入时间戳方便记录
vim.api.nvim_create_user_command('Time', function()
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	vim.api.nvim_put({ timestamp }, 'l', true, true)
end, {})

-- 设置系统粘贴板
vim.opt.clipboard = "unnamedplus"
