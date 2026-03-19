local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local fsh = require("custom.fsharp_helpers")

-- ── parse_prefix_and_delim ─────────────────────────────────────────────────
T["parse_prefix_and_delim"] = new_set()

T["parse_prefix_and_delim"]["plain string"] = function()
  local sigil, delim, cs, ce = fsh._parse_prefix_and_delim('"hello"')
  expect.equality(sigil, "")
  expect.equality(delim, '"')
  expect.equality(cs, 2)
  expect.equality(ce, 6)
end

T["parse_prefix_and_delim"]["interpolated string"] = function()
  local sigil, delim, cs, ce = fsh._parse_prefix_and_delim('$"hello {x}"')
  expect.equality(sigil, "$")
  expect.equality(delim, '"')
  expect.equality(cs, 3)
  expect.equality(ce, 11)
end

T["parse_prefix_and_delim"]["verbatim string"] = function()
  local sigil, delim = fsh._parse_prefix_and_delim('@"hello"')
  expect.equality(sigil, "@")
  expect.equality(delim, '"')
end

T["parse_prefix_and_delim"]["triple-quoted string"] = function()
  local sigil, delim, cs, ce = fsh._parse_prefix_and_delim('"""hello"""')
  expect.equality(sigil, "")
  expect.equality(delim, '"""')
  expect.equality(cs, 4)
  expect.equality(ce, 8)
end

T["parse_prefix_and_delim"]["interpolated triple"] = function()
  local sigil, delim = fsh._parse_prefix_and_delim('$"""hello"""')
  expect.equality(sigil, "$")
  expect.equality(delim, '"""')
end

T["parse_prefix_and_delim"]["non-string returns empty"] = function()
  local sigil, delim, cs, ce = fsh._parse_prefix_and_delim("42")
  expect.equality(sigil, "")
  expect.equality(delim, "")
  expect.equality(cs, nil)
  expect.equality(ce, nil)
end

-- ── collect_safe_breaks ────────────────────────────────────────────────────
T["collect_safe_breaks"] = new_set()

T["collect_safe_breaks"]["finds NICE_TOKENS in plain text"] = function()
  local breaks = fsh._collect_safe_breaks("hello, world and goodbye", false)
  expect.equality(#breaks > 0, true)
  -- Should find ", " and " and "
  local tokens = {}
  for _, b in ipairs(breaks) do
    tokens[b.tok] = true
  end
  expect.equality(tokens[", "], true)
  expect.equality(tokens[" and "], true)
end

T["collect_safe_breaks"]["skips inside braces when interpolated"] = function()
  local raw = "before {x, y} after, end"
  local breaks = fsh._collect_safe_breaks(raw, true)
  -- The ", " inside {x, y} should be skipped; only "after, end" should be found
  for _, b in ipairs(breaks) do
    if b.tok == ", " then
      -- The break should be at the ", " after "after"
      expect.equality(b.start > 14, true)
    end
  end
end

T["collect_safe_breaks"]["handles escaped braces"] = function()
  local raw = "{{escaped}}, real"
  local breaks = fsh._collect_safe_breaks(raw, true)
  expect.equality(#breaks > 0, true)
end

-- ── pick_balanced_break ────────────────────────────────────────────────────
T["pick_balanced_break"] = new_set()

T["pick_balanced_break"]["picks closest to target"] = function()
  local breaks = {
    { start = 5, tok = ", " },
    { start = 15, tok = " and " },
    { start = 25, tok = ", " },
  }
  local best = fsh._pick_balanced_break(breaks, 14)
  expect.equality(best.start, 15)
end

T["pick_balanced_break"]["returns nil for empty"] = function()
  local best = fsh._pick_balanced_break({}, 10)
  expect.equality(best, nil)
end

return T
