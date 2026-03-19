local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local child = MiniTest.new_child_neovim()
local cfg = vim.fn.stdpath("config")

T["format"] = new_set({
  hooks = {
    pre_once = function()
      child.restart({ "-u", cfg .. "/init.lua", "--cmd", "set rtp^=" .. cfg })
      child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Helper to get formatters_by_ft for a given filetype
local function get_formatters(ft)
  return child.lua_get(string.format(
    'require("conform").formatters_by_ft[%q]', ft
  ))
end

T["format"]["lua -> stylua"] = function()
  local fmts = get_formatters("lua")
  expect.equality(vim.tbl_contains(fmts, "stylua"), true)
end

T["format"]["python -> ruff_format"] = function()
  local fmts = get_formatters("python")
  expect.equality(vim.tbl_contains(fmts, "ruff_format"), true)
end

T["format"]["sh -> shfmt"] = function()
  local fmts = get_formatters("sh")
  expect.equality(vim.tbl_contains(fmts, "shfmt"), true)
end

T["format"]["fsharp -> fantomas"] = function()
  local fmts = get_formatters("fsharp")
  expect.equality(vim.tbl_contains(fmts, "fantomas"), true)
end

T["format"]["markdown includes remark"] = function()
  -- markdown entry has stop_after_first=true mixed in; check via child
  local has = child.lua_get([[
    (function()
      local fmts = require("conform").formatters_by_ft["markdown"]
      for _, v in ipairs(fmts) do
        if v == "remark" then return true end
      end
      return false
    end)()
  ]])
  expect.equality(has, true)
end

return T
