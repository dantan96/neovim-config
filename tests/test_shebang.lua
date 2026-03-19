local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local shebang = require("config.shebang")

T["shebang"] = new_set()

T["shebang"]["shebangs table has expected filetypes"] = function()
  local expected = { "python", "sh", "bash", "zsh", "javascript", "lua" }
  for _, ft in ipairs(expected) do
    expect.equality(shebang.shebangs[ft] ~= nil, true)
  end
end

T["shebang"]["default shebang is set"] = function()
  expect.equality(type(shebang.default), "string")
  expect.equality(shebang.default:match("^#!") ~= nil, true)
end

T["shebang"]["all shebangs start with #!"] = function()
  for ft, sb in pairs(shebang.shebangs) do
    expect.equality(sb:match("^#!") ~= nil, true)
  end
end

return T
