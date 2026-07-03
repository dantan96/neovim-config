local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local report = require("capture_report")

-- ── hex ────────────────────────────────────────────────────────────────────
T["hex"] = new_set()

T["hex"]["0xFF0000 -> #ff0000"] = function()
  expect.equality(report._hex(0xFF0000), "#ff0000")
end

T["hex"]["255 -> #0000ff"] = function()
  expect.equality(report._hex(255), "#0000ff")
end

T["hex"]["nil -> empty string"] = function()
  expect.equality(report._hex(nil), "")
end

T["hex"]["0 -> #000000"] = function()
  expect.equality(report._hex(0), "#000000")
end

-- ── hl() — needs child neovim for nvim_get_hl ──────────────────────────────
local child = MiniTest.new_child_neovim()

T["hl"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

T["hl"]["Normal returns table with fg/bg"] = function()
  local result = child.lua_get([[
    require("capture_report")._hl("Normal")
  ]])
  expect.equality(type(result), "table")
  expect.equality(type(result.fg), "string")
  expect.equality(type(result.bg), "string")
  expect.equality(type(result.attrs), "string")
end

T["hl"]["nonexistent group returns empty colors"] = function()
  local result = child.lua_get([[
    require("capture_report")._hl("ZZZNonExistentHighlight")
  ]])
  expect.equality(result.fg, "")
  expect.equality(result.bg, "")
end

T["hl"]["italic-only group does not crash and reports italic"] = function()
  -- Regression: attrs was built as { bold or nil, italic or nil, ... },
  -- embedding nils; table.concat crashed for italic-only groups.
  child.lua([[vim.api.nvim_set_hl(0, "TestCapRepItalicOnly", { italic = true })]])
  local result = child.lua_get([[
    require("capture_report")._hl("TestCapRepItalicOnly")
  ]])
  expect.equality(result.attrs, "italic")
end

T["hl"]["bold+underline group reports both flags"] = function()
  child.lua([[vim.api.nvim_set_hl(0, "TestCapRepBoldUl", { bold = true, underline = true })]])
  local result = child.lua_get([[
    require("capture_report")._hl("TestCapRepBoldUl")
  ]])
  expect.equality(result.attrs, "bold underline")
end

T["hl"]["follows link chain"] = function()
  -- Create a link: TestCapRepLink → Normal
  child.lua([[vim.api.nvim_set_hl(0, "TestCapRepLink", { link = "Normal" })]])
  local result = child.lua_get([[
    require("capture_report")._hl("TestCapRepLink")
  ]])
  local normal = child.lua_get([[
    require("capture_report")._hl("Normal")
  ]])
  -- Should resolve to Normal's fg color
  expect.equality(result.fg, normal.fg)
end

-- ── build_rows() ───────────────────────────────────────────────────────────
T["build_rows"] = new_set({
  hooks = {
    pre_once = function()
      -- reuse the same child from hl tests if still running
      if not child.is_running() then H.setup_child(child) end
    end,
  },
})

T["build_rows"]["report buffer starts with title, no blank first line"] = function()
  child.lua([[require("capture_report").run()]])
  local first = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ]])
  expect.equality(first:find("Capture") ~= nil, true)
end

T["build_rows"]["empty captures returns header only"] = function()
  local result = child.lua_get([[
    require("capture_report")._build_rows({})
  ]])
  expect.equality(#result, 1) -- header only
  expect.equality(result[1][1], "capture")
end

T["build_rows"]["single capture returns header + 1 row"] = function()
  local result = child.lua_get([[
    require("capture_report")._build_rows({ keyword = true })
  ]])
  expect.equality(#result, 2)
  expect.equality(result[2][1], "keyword")
end

return T
