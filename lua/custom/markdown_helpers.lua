-- lua/custom/markdown_helpers.lua
local M = {}

-- lua/custom/markdown_helpers.lua (replace M.project_root)
function M.project_root(start)
  local cfgdir = vim.fn.stdpath("config")
  start = (start and start ~= "" and start) or vim.api.nvim_buf_get_name(0)
  if start == "" then
    start = vim.fn.getcwd()
  end

  local hit = vim.fs.find({
    ".git",
    ".marksman.toml",
    "marksman.toml",
    ".remarkrc.mjs",
    ".remarkrc.js",
    ".remarkrc.cjs",
    ".remarkrc",
    ".remarkrc.json",
    ".remarkrc.yaml",
    ".remarkrc.yml",
    "remark.config.mjs",
    "remark.config.js",
    "remark.config.cjs",
  }, { path = start, upward = true })[1]

  local root = hit and vim.fs.dirname(hit) or vim.fs.dirname(start)
  if not start:find(cfgdir, 1, true) and root:find(cfgdir, 1, true) then
    root = vim.fs.dirname(start)
  end
  return root
end

function M.find_marksman_config(root)
  for _, name in ipairs({ ".marksman.toml", "marksman.toml" }) do
    local p = root .. "/" .. name
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
end

function M.find_remark_config(root)
  for _, name in ipairs({
    ".remarkrc.mjs",
    ".remarkrc.js",
    ".remarkrc.cjs",
    ".remarkrc",
    ".remarkrc.json",
    ".remarkrc.yaml",
    ".remarkrc.yml",
    "remark.config.mjs",
    "remark.config.js",
    "remark.config.cjs",
  }) do
    local p = root .. "/" .. name
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
end

return M
