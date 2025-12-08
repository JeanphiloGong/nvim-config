-- 插件分类：通用 / 生产加速 / 前端 / 后端
local specs = {}

for _, mod in ipairs({ "plugins.common", "plugins.productivity", "plugins.frontend", "plugins.backend" }) do
  local ok, list = pcall(require, mod)
  if ok and type(list) == "table" then
    vim.list_extend(specs, list)
  end
end

return specs
