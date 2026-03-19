local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local report = require("capture_report")

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

return T
