# 📘 Neovim Markdown 插件配置指南
<!-- vim-markdown-toc GFM -->

* [📦 使用的插件（Lazy.nvim）](#-使用的插件lazynvim)
* [🧩 插件配置（用于 Lazy.nvim）](#-插件配置用于-lazynvim)
* [⚙️ 额外优化设置](#-额外优化设置)
* [⌨️ 快捷键绑定（推荐）](#-快捷键绑定推荐)
* [🚀 插件使用说明](#-插件使用说明)
  * [📄 写 Markdown](#-写-markdown)
  * [🌐 预览 Markdown](#-预览-markdown)
  * [📑 生成 TOC 目录](#-生成-toc-目录)
* [🔧 注意事项](#-注意事项)
* [✅ 总结](#-总结)

<!-- vim-markdown-toc -->

本指南帮助你在 Neovim 中快速搭建一个高效的 Markdown 写作环境，适合写文档、博客、笔记等。

---

## 📦 使用的插件（Lazy.nvim）

| 插件名称 | 功能说明 |
|----------|-----------|
| [`vim-markdown`](https://github.com/preservim/vim-markdown) | 增强 Markdown 的语法支持、TOC、折叠等 |
| [`vim-markdown-toc`](https://github.com/mzlogin/vim-markdown-toc) | 自动生成和更新 Markdown 的目录 |
| [`markdown-preview.nvim`](https://github.com/iamcco/markdown-preview.nvim) | 浏览器实时预览 Markdown 文档 |

---

## 🧩 插件配置（用于 Lazy.nvim）

将以下代码放入你的 `lua/plugins/markdown.lua` 文件中：

```lua
return {
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
    "mzlogin/vim-markdown-toc",
    ft = { "markdown" },
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
}
```

---

## ⚙️ 额外优化设置

放在 `lua/options.lua` 或 `init.lua` 中，增强 Markdown 体验：

```lua
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
```

---

## ⌨️ 快捷键绑定（推荐）

放入 `lua/keymaps.lua` 或你的快捷键配置文件：

```lua
vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { desc = "Markdown 预览" })
vim.keymap.set("n", "<leader>mt", "<cmd>GenTocGFM<cr>", { desc = "生成目录 TOC" })
vim.keymap.set("n", "<leader>mu", "<cmd>UpdateToc<cr>", { desc = "更新目录 TOC" })
```

默认 `<leader>` 是 `\`，你也可以加这行改为空格：

```lua
vim.g.mapleader = " "
```

然后 `<leader>mp` 就是按：空格 + m + p

---

## 🚀 插件使用说明

### 📄 写 Markdown
使用 `nvim xxx.md` 打开 Markdown 文件，编辑时自动换行、拼写检查生效。

### 🌐 预览 Markdown
按 `<leader>mp`（如 空格 + m + p）启动浏览器预览，实时同步。

### 📑 生成 TOC 目录
- 插入目录：`<leader>mt`
- 更新目录：`<leader>mu`

---

## 🔧 注意事项

- `markdown-preview.nvim` 依赖 Node.js：
  ```bash
  node -v
  npm install -g markdown-preview
  ```
- 必须在加载 Lazy.nvim 之前设置 `vim.g.mapleader`！

  ```lua
  vim.g.mapleader = " "
  ```

---

## ✅ 总结

你现在拥有：

- 快捷键高效写作
- 实时预览 & 目录生成
- 自动排版 & 拼写优化

写文档不要太爽～！

