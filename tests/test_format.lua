local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["format"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
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
  -- fantomas is installed as a dotnet global tool in ~/.dotnet/tools.
  local fmts = get_formatters("fsharp")
  expect.equality(vim.tbl_contains(fmts, "fantomas"), true)
end

T["format"]["toml -> taplo"] = function()
  local fmts = get_formatters("toml")
  expect.equality(vim.tbl_contains(fmts, "taplo"), true)
end

T["format"]["hardwrap_off suppresses format_on_save"] = function()
  -- format_on_save is a function; it must return nil (skip) when the
  -- buffer's hard-wrap toggle is off, and a table otherwise.
  local on = child.lua_get([[
    (function()
      vim.b.hardwrap_off = nil
      local p = require("lazy.core.config").plugins["conform.nvim"]
      local fos = require("lazy.core.plugin").values(p, "opts", false).format_on_save
      return type(fos) == "function" and type(fos(0)) == "table"
    end)()
  ]])
  expect.equality(on, true)
  local off = child.lua_get([[
    (function()
      vim.b.hardwrap_off = true
      local p = require("lazy.core.config").plugins["conform.nvim"]
      local fos = require("lazy.core.plugin").values(p, "opts", false).format_on_save
      local r = fos(0) == nil
      vim.b.hardwrap_off = nil
      return r
    end)()
  ]])
  expect.equality(off, true)
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
