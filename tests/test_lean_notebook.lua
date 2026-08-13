-- tests/test_lean_notebook.lua — reading a literate Lean file as a notebook
-- (lua/config/lean/notebook.lua + lua/config/lean/exercises.lua).
--
-- WHAT THESE TESTS CAN AND CANNOT SEE:
--
--   * Block and heading extraction is pure tree-sitter over buffer text, and
--     works headless.
--   * The cell views are extmarks set by our own code, not by a decoration
--     provider, so their presence IS observable headless — unlike markview's,
--     which are not (GOTCHAS A1).
--   * The exercise list reads `vim.diagnostic`, and no Lean server runs here.
--     Rather than skip it, the diagnostics are INJECTED with vim.diagnostic.set,
--     which makes the message-matching testable — and that is the part that was
--     actually wrong: the server writes "declaration uses `sorry`" with
--     backticks, a straight-quoted constant matched nothing, and the failure
--     presented as "this file has no exercises".

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

-- A miniature literate file: two prose blocks, a heading, three declarations.
local FIXTURE = {
  "import MIL.Common",
  "",
  "/-!",
  "## A Section",
  "",
  "Some prose about it.",
  "-/",
  "",
  "example : 1 = 1 := rfl",
  "",
  "/-!",
  "More prose, with no heading of its own.",
  "-/",
  "",
  "example (a : Nat) : a = a := by",
  "  sorry",
  "",
  "example (b : Nat) : b + 0 = b := by",
  "  sorry",
}

-- Each case gets its own buffer NAME. Reusing one raises E95 ("Buffer with this
-- name already exists") from the second case onward, which is a fixture failure
-- that reads exactly like a code failure.
local case = 0
local function setup_buf()
  case = case + 1
  return child.lua_get(([[
    (function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, %s)
      vim.api.nvim_buf_set_name(buf, "/tmp/lean-notebook-test/MILbook/C99/S%02d_Test.lean")
      vim.bo[buf].filetype = "lean"
      vim.api.nvim_set_current_buf(buf)
      vim.b[buf].lean_prose_on = true
      return buf
    end)()
  ]]):format(vim.inspect(FIXTURE), case))
end

T["notebook"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["notebook"]["finds prose blocks and headings"] = function()
  setup_buf()
  local r = child.lua_get([[
    (function()
      local prose = require("config.lean.prose")
      local buf = vim.api.nvim_get_current_buf()
      local blocks, headings = prose.blocks(buf), prose.headings(buf)
      return { blocks = #blocks, headings = #headings,
               first_heading = headings[1] and headings[1].text or "",
               level = headings[1] and headings[1].level or 0,
               first_block_first = blocks[1] and blocks[1].first or -1 }
    end)()
  ]])
  expect.equality(r.blocks, 2)
  expect.equality(r.headings, 1)
  expect.equality(r.first_heading, "A Section")
  expect.equality(r.level, 2)
  expect.equality(r.first_block_first, 2) -- the `/-!` row, 0-indexed
end

-- Headings alone are too thin: one `##` against twenty blocks in a real file.
T["notebook"]["outlines unheaded blocks and exercises too"] = function()
  setup_buf()
  local kinds = child.lua_get([[
    (function()
      vim.diagnostic.set(vim.api.nvim_create_namespace("test_lean"), 0, {
        { lnum = 14, col = 0, message = "declaration uses `sorry`", severity = vim.diagnostic.severity.WARN },
      })
      local entries = require("config.lean.notebook").entries(0)
      local out = {}
      for _, e in ipairs(entries) do out[#out+1] = e.kind end
      return out
    end)()
  ]])
  expect.equality(vim.tbl_contains(kinds, "heading"), true)
  expect.equality(vim.tbl_contains(kinds, "prose"), true)
  expect.equality(vim.tbl_contains(kinds, "exercise"), true)
end

-- The bug this file exists for.
T["notebook"]["matches the server's backticked sorry message"] = function()
  setup_buf()
  local r = child.lua_get([[
    (function()
      local ex = require("config.lean.exercises")
      local ns = vim.api.nvim_create_namespace("test_lean")
      local function count(msg)
        vim.diagnostic.reset(ns, 0)
        vim.diagnostic.set(ns, 0, {
          { lnum = 14, col = 0, message = msg, severity = vim.diagnostic.severity.WARN },
        })
        return #ex.unsolved(0)
      end
      return {
        backticks = count("declaration uses `sorry`"),
        straight = count("declaration uses 'sorry'"),
        unrelated = count("unknown identifier 'foo'"),
      }
    end)()
  ]])
  expect.equality(r.backticks, 1) -- what the server actually sends
  expect.equality(r.straight, 1) -- and the other quoting, so a change degrades gracefully
  expect.equality(r.unrelated, 0) -- but not just any diagnostic
end

T["notebook"]["cell views hide one half and keep the imports"] = function()
  setup_buf()
  local r = child.lua_get([[
    (function()
      local nb = require("config.lean.notebook")
      local ns = function() return vim.api.nvim_get_namespaces()["lean_notebook_view"] end
      local function hidden()
        local n = ns()
        return n and #vim.api.nvim_buf_get_extmarks(0, n, 0, -1, {}) or 0
      end
      nb.set_view("code", 0); local code = hidden()
      nb.set_view("prose", 0); local prose = hidden()
      nb.set_view("both", 0); local both = hidden()
      -- The import line must stay visible in every view.
      nb.set_view("prose", 0)
      local n = ns()
      local import_hidden = false
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, n, 0, -1, {})) do
        if m[2] == 0 then import_hidden = true end
      end
      nb.set_view("both", 0)
      return { code = code, prose = prose, both = both, import_hidden = import_hidden,
               total = vim.api.nvim_buf_line_count(0) }
    end)()
  ]])
  expect.equality(r.both, 0)
  expect.equality(r.code > 0, true)
  expect.equality(r.prose > 0, true)
  -- Between them the two views account for every line except the kept imports.
  expect.equality(r.code + r.prose <= r.total, true)
  expect.equality(r.import_hidden, false)
end

T["notebook"]["reveals a solution, by statement and by normalised statement"] = function()
  setup_buf()
  local r = child.lua_get([[
    (function()
      vim.fn.mkdir("/tmp/lean-notebook-test/MILbook/C99", "p")
      -- Key off the buffer's actual name: the fixture numbers each case's file
      -- differently, so a hardcoded key would silently test nothing.
      local name = vim.api.nvim_buf_get_name(0)
      local rel = name:sub(#"/tmp/lean-notebook-test/MILbook/" + 1)
      local index = {
        [rel] = {
          { key = "example (a : Nat) : a = a := by",
            nkey = "example (a : Nat) : a = a",
            solution = { "example (a : Nat) : a = a := by", "  rfl" } },
          -- Stored with a different proof tail from the exercise's, which is the
          -- case the normalised key exists for.
          { key = "example (b : Nat) : b + 0 = b :=",
            nkey = "example (b : Nat) : b + 0 = b",
            solution = { "example (b : Nat) : b + 0 = b :=", "  Nat.add_zero b" } },
        },
      }
      vim.fn.writefile({ vim.json.encode(index) },
        "/tmp/lean-notebook-test/MILbook/solutions-index.json")

      local ex = require("config.lean.exercises")
      -- Inside the first exercise (its `sorry` line).
      vim.api.nvim_win_set_cursor(0, { 16, 0 })
      local sol1 = ex.solution_here(0)
      -- Inside the second, whose stored key has a different tail.
      vim.api.nvim_win_set_cursor(0, { 19, 0 })
      local sol2 = ex.solution_here(0)
      -- Above every exercise: nothing to reveal.
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local sol0 = ex.solution_here(0)
      return {
        one = sol1 and sol1[2] or "",
        two = sol2 and sol2[2] or "",
        none = sol0 == nil,
      }
    end)()
  ]])
  expect.equality(r.one, "  rfl")
  expect.equality(r.two, "  Nat.add_zero b")
  expect.equality(r.none, true)
end

return T
