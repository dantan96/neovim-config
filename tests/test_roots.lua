local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local roots = require("config.roots")

-- ── marker tables ──────────────────────────────────────────────────────────
T["markers"] = new_set()

T["markers"]["marksman_markers non-empty"] = function()
  expect.equality(#roots.marksman_markers > 0, true)
end

T["markers"]["remark_markers non-empty"] = function()
  expect.equality(#roots.remark_markers > 0, true)
end

T["markers"]["all_markers combines both"] = function()
  expect.equality(
    #roots.all_markers >= #roots.marksman_markers + #roots.remark_markers,
    true
  )
end

-- ── find() ─────────────────────────────────────────────────────────────────
T["find"] = new_set()

local tmproot

T["find"]["returns root when .git found"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot .. "/sub", "p")
  vim.fn.mkdir(tmproot .. "/.git", "p")
  local result = roots.find(tmproot .. "/sub/file.md", roots.marksman_markers)
  expect.equality(result, tmproot)
  vim.fn.delete(tmproot, "rf")
end

T["find"]["returns nil when root would be home"] = function()
  local home = vim.fn.expand("~")
  vim.fn.mkdir(home .. "/.git", "p")
  local result = roots.find(home .. "/somefile.md", { ".git" })
  -- Should be nil because root == home
  expect.equality(result, nil)
  vim.fn.delete(home .. "/.git", "rf")
end

T["find"]["returns dirname when no markers found"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot .. "/sub", "p")
  local result = roots.find(tmproot .. "/sub/file.md", { ".nonexistent_marker" })
  expect.equality(result, tmproot .. "/sub")
  vim.fn.delete(tmproot, "rf")
end

-- ── find_marksman_config() ─────────────────────────────────────────────────
T["find_marksman_config"] = new_set()

T["find_marksman_config"]["finds .marksman.toml"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot, "p")
  local f = io.open(tmproot .. "/.marksman.toml", "w")
  f:write("")
  f:close()
  expect.equality(roots.find_marksman_config(tmproot), tmproot .. "/.marksman.toml")
  vim.fn.delete(tmproot, "rf")
end

T["find_marksman_config"]["finds marksman.toml"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot, "p")
  local f = io.open(tmproot .. "/marksman.toml", "w")
  f:write("")
  f:close()
  expect.equality(roots.find_marksman_config(tmproot), tmproot .. "/marksman.toml")
  vim.fn.delete(tmproot, "rf")
end

T["find_marksman_config"]["returns nil when no config"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot, "p")
  expect.equality(roots.find_marksman_config(tmproot), nil)
  vim.fn.delete(tmproot, "rf")
end

T["find_marksman_config"]["returns nil for nil root"] = function()
  expect.equality(roots.find_marksman_config(nil), nil)
end

-- ── find_remark_config() ───────────────────────────────────────────────────
T["find_remark_config"] = new_set()

T["find_remark_config"]["finds .remarkrc.json"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot, "p")
  local f = io.open(tmproot .. "/.remarkrc.json", "w")
  f:write("")
  f:close()
  expect.equality(roots.find_remark_config(tmproot), tmproot .. "/.remarkrc.json")
  vim.fn.delete(tmproot, "rf")
end

T["find_remark_config"]["returns nil when no config"] = function()
  tmproot = vim.fn.tempname()
  vim.fn.mkdir(tmproot, "p")
  expect.equality(roots.find_remark_config(tmproot), nil)
  vim.fn.delete(tmproot, "rf")
end

T["find_remark_config"]["returns nil for nil root"] = function()
  expect.equality(roots.find_remark_config(nil), nil)
end

return T
