local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local peek = require("config.markdown.peek_auto")

T["has_latex"] = new_set()

T["has_latex"]["detects \\("] = function()
  expect.equality(peek.has_latex("inline \\( x^2 \\) math"), true)
end

T["has_latex"]["detects \\["] = function()
  expect.equality(peek.has_latex("display \\[ E=mc^2 \\]"), true)
end

T["has_latex"]["detects $$...$$"] = function()
  expect.equality(peek.has_latex("display $$x^2$$ math"), true)
end

T["has_latex"]["detects $...$"] = function()
  expect.equality(peek.has_latex("inline $x^2$ math"), true)
end

T["has_latex"]["returns false for plain text"] = function()
  expect.equality(peek.has_latex("just plain text"), false)
end

T["has_latex"]["returns false for empty string"] = function()
  expect.equality(peek.has_latex(""), false)
end

return T
