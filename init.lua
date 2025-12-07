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

-- 按语言设置缩进宽度
local indent_by_ft = {
  -- 2 spaces
  javascript = { size = 2, expandtab = true },
  javascriptreact = { size = 2, expandtab = true },
  typescript = { size = 2, expandtab = true },
  typescriptreact = { size = 2, expandtab = true },
  svelte = { size = 2, expandtab = true },
  html = { size = 2, expandtab = true },
  markdown = { size = 2, expandtab = true },
  -- 4 spaces
  c = { size = 4, expandtab = true },
  cpp = { size = 4, expandtab = true },
  rust = { size = 4, expandtab = true },
  python = { size = 4, expandtab = true },
  -- Tabs for Go (gofmt)
  go = { size = 4, expandtab = false, soft = 4 },
}

local indent_group = vim.api.nvim_create_augroup("IndentByFiletype", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = "*",
  callback = function(args)
    local cfg = indent_by_ft[args.match]
    if not cfg then
      return
    end
    local size = cfg.size or 4
    vim.opt_local.tabstop = size
    vim.opt_local.shiftwidth = size
    vim.opt_local.softtabstop = cfg.soft or size
    if cfg.expandtab ~= nil then
      vim.opt_local.expandtab = cfg.expandtab
    end
  end,
})

-- 自动优化 Markdown 编辑体验
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
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
