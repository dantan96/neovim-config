-- lua/config/roots.lua
-- Shared root-directory discovery for markdown LSPs and ftplugin.

local M = {}

M.marksman_markers = { ".git", ".marksman.toml", "marksman.toml" }

M.remark_markers = {
  ".remarkrc.mjs", ".remarkrc.js", ".remarkrc.cjs",
  ".remarkrc", ".remarkrc.json", ".remarkrc.yaml", ".remarkrc.yml",
  "remark.config.mjs", "remark.config.js", "remark.config.cjs",
}

M.all_markers = vim.list_extend(
  vim.list_extend({}, M.remark_markers),
  M.marksman_markers
)

--- Find project root by searching upward for marker files.
--- Avoids rooting to the Neovim config dir or home directory.
---@param start string|nil  starting path (defaults to current buffer or cwd)
---@param markers string[]  file/dir names to search for
---@return string|nil root  project root, or nil if only ~ matched
function M.find(start, markers)
  local cfgdir = vim.fn.stdpath("config")
  local home = vim.fn.expand("~")
  start = (type(start) == "string" and #start > 0) and start
    or vim.api.nvim_buf_get_name(0)
  if start == "" then
    start = vim.fn.getcwd()
  end

  -- start may be a file (use its directory) or already a directory, e.g.
  -- the getcwd() fallback for unnamed buffers (use it as-is — dirname
  -- would wrongly land one level too high).
  local start_dir = vim.fn.isdirectory(start) == 1 and start
    or vim.fs.dirname(start)

  local hit = vim.fs.find(markers, { path = start, upward = true })[1]
  local root = hit and vim.fs.dirname(hit) or start_dir

  -- avoid accidentally rooting to Neovim config dir
  if not start:find(cfgdir, 1, true) and root:find(cfgdir, 1, true) then
    root = start_dir
  end

  -- avoid using ~ as workspace root (marksman scans everything and crashes)
  if root == home then
    return nil
  end

  return root
end

function M.find_marksman_config(root)
  if not root then return nil end
  for _, name in ipairs({ ".marksman.toml", "marksman.toml" }) do
    local p = root .. "/" .. name
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
end

function M.find_remark_config(root)
  if not root then return nil end
  for _, name in ipairs(M.remark_markers) do
    local p = root .. "/" .. name
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
end

return M
