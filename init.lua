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

-- 加载 plugins 目录下的插件配置（分组后汇总）
require("lazy").setup(require("plugins"))

-- Mermaid filetypes
vim.filetype.add({
  extension = {
    mmd = "mermaid",
    mermaid = "mermaid",
  },
})

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
  mermaid = { size = 2, expandtab = true },
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

-- 保存 Mermaid 文件时自动导出 SVG（依赖 mmdc + MermaidToSvg 命令）
local mermaid_export_group = vim.api.nvim_create_augroup("MermaidAutoExport", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  group = mermaid_export_group,
  pattern = { "*.mmd", "*.mermaid" },
  callback = function()
    if vim.fn.executable("mmdc") ~= 1 then
      return
    end
    if vim.fn.exists(":MermaidToSvg") ~= 2 then
      return
    end
    vim.cmd("silent MermaidToSvg")
  end,
})

-- 设置加入时间戳方便记录
vim.api.nvim_create_user_command('Time', function()
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	vim.api.nvim_put({ timestamp }, 'l', true, true)
end, {})

-- Use OSC 52 over SSH so yanks reach the terminal on the client machine.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end

-- 设置系统粘贴板
vim.opt.clipboard = "unnamedplus"

-- 光标样式与颜色（按模式区分）
vim.opt.guicursor = table.concat({
  "n:block-Cursor",
  "v:block-CursorVisual",
  "i:ver25-CursorInsert",
  "c:block-CursorCommand",
  "r:hor20-CursorReplace",
  "o:hor50-CursorReplace",
  "sm:block-Cursor",
}, ",")

local function set_cursor_style()
  vim.api.nvim_set_hl(0, "Cursor", { fg = "#1b1b1b", bg = "#f2a65a" })
  vim.api.nvim_set_hl(0, "CursorInsert", { fg = "#1b1b1b", bg = "#4cc9f0" })
  vim.api.nvim_set_hl(0, "CursorVisual", { fg = "#1b1b1b", bg = "#c77dff" })
  vim.api.nvim_set_hl(0, "CursorCommand", { fg = "#1b1b1b", bg = "#80ed99" })
  vim.api.nvim_set_hl(0, "CursorReplace", { fg = "#1b1b1b", bg = "#ff6b6b" })
  vim.api.nvim_set_hl(0, "TermCursor", { fg = "#1b1b1b", bg = "#f2a65a" })
  vim.api.nvim_set_hl(0, "TermCursorNC", { fg = "#1b1b1b", bg = "#666666" })
end

local cursor_group = vim.api.nvim_create_augroup("CursorStyle", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = cursor_group,
  callback = set_cursor_style,
})
set_cursor_style()

local function set_transparent_background()
  for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "EndOfBuffer" }) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE" })
  end
end

local transparent_group = vim.api.nvim_create_augroup("TransparentBackground", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent_group,
  callback = set_transparent_background,
})
set_transparent_background()
