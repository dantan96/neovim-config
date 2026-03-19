local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local remark = require("config.remark_auto")

T["find_init_root"] = new_set()

local home = vim.fn.expand("~")
-- Use a temp dir under ~ so the module's home-guard passes
local test_base = home .. "/.test_remark_auto_" .. vim.fn.getpid()

T["find_init_root"]["setup"] = new_set({
  hooks = {
    pre_once = function()
      vim.fn.mkdir(test_base, "p")
    end,
    post_once = function()
      vim.fn.delete(test_base, "rf")
    end,
  },
})

T["find_init_root"]["setup"]["returns nil for home dir itself"] = function()
  expect.equality(remark._find_init_root(home .. "/file.md"), nil)
end

T["find_init_root"]["setup"]["returns nil for path outside home"] = function()
  expect.equality(remark._find_init_root("/tmp/outside/file.md"), nil)
end

T["find_init_root"]["setup"]["returns git root when .git exists"] = function()
  local dir = test_base .. "/proj"
  vim.fn.mkdir(dir .. "/sub", "p")
  vim.fn.mkdir(dir .. "/.git", "p")
  local result = remark._find_init_root(dir .. "/sub/file.md")
  expect.equality(result, dir)
  vim.fn.delete(dir, "rf")
end

T["find_init_root"]["setup"]["returns file dir when no .git found"] = function()
  local dir = test_base .. "/noproj/sub"
  vim.fn.mkdir(dir, "p")
  local result = remark._find_init_root(dir .. "/file.md")
  expect.equality(result, dir)
  vim.fn.delete(test_base .. "/noproj", "rf")
end

T["find_init_root"]["setup"]["returns nil when remarkrc already exists"] = function()
  local dir = test_base .. "/hasrc"
  vim.fn.mkdir(dir, "p")
  local f = io.open(dir .. "/.remarkrc.json", "w")
  f:write("{}")
  f:close()
  expect.equality(remark._find_init_root(dir .. "/file.md"), nil)
  vim.fn.delete(dir, "rf")
end

T["find_init_root"]["setup"]["returns nil when remark-gfm installed"] = function()
  local dir = test_base .. "/hasgfm"
  vim.fn.mkdir(dir .. "/node_modules/remark-gfm", "p")
  expect.equality(remark._find_init_root(dir .. "/file.md"), nil)
  vim.fn.delete(dir, "rf")
end

return T
