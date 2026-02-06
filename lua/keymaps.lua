vim.keymap.set("n", "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Toggle NeoTree" })
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle source=filesystem position=left<cr>", { desc = "NeoTree Files" })
vim.keymap.set("n", "<leader>gs", "<cmd>Neotree toggle source=git_status position=float<cr>", { desc = "NeoTree Git Status" })
vim.keymap.set("n", "<leader>be", "<cmd>Neotree toggle source=buffers position=left<cr>", { desc = "NeoTree Buffers" })

local function copy_path(style)
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("No file name", vim.log.levels.WARN)
    return
  end

  if style == "absolute" then
    path = vim.fn.fnamemodify(path, ":p")
  elseif style == "relative" then
    path = vim.fn.fnamemodify(path, ":.")
  end

  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end

vim.keymap.set("n", "<leader>yp", function()
  copy_path("absolute")
end, { desc = "Yank absolute path" })
vim.keymap.set("n", "<leader>yr", function()
  copy_path("relative")
end, { desc = "Yank relative path" })

-- Markdown 快捷键
vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { desc = "Markdown 预览" })
vim.keymap.set("n", "<leader>mt", "<cmd>GenTocGFM<cr>", { desc = "生成目录 TOC" })
vim.keymap.set("n", "<leader>mu", "<cmd>UpdateToc<cr>", { desc = "更新目录 TOC" })

local active_mermaid_jobs = {}

local function trim_output(text)
  if not text then
    return ""
  end
  return tostring(text):gsub("%s+$", "")
end

local function export_mermaid(format)
  local input = vim.api.nvim_buf_get_name(0)
  if input == "" then
    vim.notify("请先保存 Mermaid 文件", vim.log.levels.WARN)
    return
  end

  local filetype = vim.bo.filetype
  local ext = vim.fn.fnamemodify(input, ":e")
  local is_mermaid = filetype == "mermaid" or ext == "mmd" or ext == "mermaid"
  if not is_mermaid then
    vim.notify("仅支持 .mmd / .mermaid 文件导出", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified then
    vim.notify("文件有未保存修改，请先 :w", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("mmdc") ~= 1 then
    vim.notify("未找到 mmdc，请先安装: npm install -g @mermaid-js/mermaid-cli", vim.log.levels.ERROR)
    return
  end

  local abs_input = vim.fn.fnamemodify(input, ":p")
  local output = vim.fn.fnamemodify(abs_input, ":r") .. "." .. format
  local job_key = abs_input .. "::" .. format
  local prev_job = active_mermaid_jobs[job_key]

  if prev_job and prev_job.handle then
    prev_job.cancelled = true
    pcall(function()
      prev_job.handle:kill(15)
    end)
  end

  local current_job = { cancelled = false, handle = nil }
  active_mermaid_jobs[job_key] = current_job

  local ok, handle_or_err = pcall(vim.system, { "mmdc", "-i", abs_input, "-o", output }, { text = true }, function(obj)
    vim.schedule(function()
      if active_mermaid_jobs[job_key] ~= current_job then
        return
      end
      active_mermaid_jobs[job_key] = nil

      if current_job.cancelled then
        return
      end

      if obj.code ~= 0 then
        local msg = trim_output(obj.stderr)
        if msg == "" then
          msg = trim_output(obj.stdout)
        end
        if msg == "" then
          msg = "未知错误"
        end
        vim.notify("Mermaid 导出失败: " .. msg, vim.log.levels.ERROR)
        return
      end

      vim.notify("Mermaid 导出成功: " .. output)
    end)
  end)

  if not ok then
    active_mermaid_jobs[job_key] = nil
    vim.notify("Mermaid 导出失败: " .. trim_output(handle_or_err), vim.log.levels.ERROR)
    return
  end

  current_job.handle = handle_or_err
end

if vim.fn.exists(":MermaidToSvg") == 2 then
  vim.api.nvim_del_user_command("MermaidToSvg")
end
if vim.fn.exists(":MermaidToPng") == 2 then
  vim.api.nvim_del_user_command("MermaidToPng")
end

vim.api.nvim_create_user_command("MermaidToSvg", function()
  export_mermaid("svg")
end, { desc = "导出当前 Mermaid 为 SVG" })

vim.api.nvim_create_user_command("MermaidToPng", function()
  export_mermaid("png")
end, { desc = "导出当前 Mermaid 为 PNG" })

vim.keymap.set("n", "<leader>ms", function()
  export_mermaid("svg")
end, { desc = "Mermaid 导出 SVG" })

vim.keymap.set("n", "<leader>mn", function()
  export_mermaid("png")
end, { desc = "Mermaid 导出 PNG" })
