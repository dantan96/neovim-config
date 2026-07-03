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

T["format"]["fsharp has no conform formatter (falls back to LSP)"] = function()
  -- fantomas is not installed; fsharp must not have a conform entry so
  -- formatting falls through to the LSP via lsp_format fallback.
  local fmts = get_formatters("fsharp")
  expect.equality(fmts == vim.NIL or fmts == nil or #fmts == 0, true)
end

T["format"]["toml -> taplo"] = function()
  local fmts = get_formatters("toml")
  expect.equality(vim.tbl_contains(fmts, "taplo"), true)
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
