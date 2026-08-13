-- tests/test_lean_prose.lua — Markdown rendering inside `/-! -/` blocks
-- (lua/config/lean/prose.lua, parser/leantiny.so, queries/leantiny/injections.scm).
--
-- WHAT THESE TESTS CAN AND CANNOT SEE, stated up front:
--
--   * The PARSER and the INJECTION QUERY work headless. Tree-sitter parses
--     whether or not anything is drawn, so "how many module doc comments does
--     leantiny find" and "does the query produce markdown regions" are real
--     observations here.
--   * MARKVIEW'S EXTMARKS DO NOT, for the same reason semantic tokens do not
--     (GOTCHAS A1): they come from a decoration provider and there is no window
--     being drawn. Asserting an extmark count here could only pass vacuously.
--     That half is verified out of band against a pty-hosted TUI, which
--     measured 315 extmarks on MILbook/C03_Logic/S02 (inline=210, latex=104,
--     markdown=1) with the code cells still reporting
--     `semantic=[@lsp.type.keyword.lean@125]` and `treesitter=[]`.
--
-- The decision the module makes on its own — WHICH buffers render without being
-- asked — is pure, and is checked directly.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["lean prose"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["lean prose"]["ships the leantiny parser"] = function()
  local found = child.lua_get([[vim.api.nvim_get_runtime_file("parser/leantiny.so", false)]])
  expect.equality(#found > 0, true)
end

T["lean prose"]["the parser loads"] = function()
  local ok = child.lua_get([[pcall(vim.treesitter.language.add, "leantiny")]])
  expect.equality(ok, true)
end

T["lean prose"]["the injection query parses and targets markdown"] = function()
  local q = child.lua_get([[
    (function()
      local ok, err = pcall(vim.treesitter.query.get, "leantiny", "injections")
      if not ok then return "ERROR: " .. tostring(err) end
      local files = vim.api.nvim_get_runtime_file("queries/leantiny/injections.scm", false)
      if #files == 0 then return "ERROR: no injections.scm" end
      return table.concat(vim.fn.readfile(files[1]), "\n")
    end)()
  ]])
  expect.equality(q:find("ERROR:") == nil, true)
  expect.equality(q:find('injection.language "markdown"', 1, true) ~= nil, true)
  expect.equality(q:find("module_doc_comment", 1, true) ~= nil, true)
end

-- The point of leantiny over Julian/tree-sitter-lean: it finds EVERY doc
-- comment, because a grammar whose fallback token matches any byte cannot fail.
-- Break it by making the fixture's prose unbalanced and this count moves.
T["lean prose"]["finds every module doc comment in a literate file"] = function()
  local n = child.lua_get([[
    (function()
      local src = table.concat({
        "import MIL.Common",
        "",
        "/-!",
        "# A heading",
        "",
        "Prose with `code` and $x + y$.",
        "-/",
        "",
        "example : 1 = 1 := rfl",
        "",
        "/-!",
        "More prose.",
        "-/",
        "",
        "example : 2 = 2 := rfl",
      }, "\n")
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(src, "\n"))
      local parser = vim.treesitter.get_parser(buf, "leantiny")
      local tree = parser:parse()[1]
      local query = vim.treesitter.query.parse("leantiny", "((module_doc_comment) @c)")
      local count = 0
      for _ in query:iter_captures(tree:root(), buf) do count = count + 1 end
      return count
    end)()
  ]])
  expect.equality(n, 2)
end

T["lean prose"]["injects markdown, and trims the delimiters"] = function()
  local langs = child.lua_get([[
    (function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "import MIL.Common", "", "/-!", "# Heading", "", "Some *prose*.", "-/", "",
        "example : 1 = 1 := rfl",
      })
      local parser = vim.treesitter.get_parser(buf, "leantiny")
      parser:parse(true)
      local seen = {}
      parser:for_each_tree(function(tree, lt)
        if lt:lang() == "markdown" then
          local first = vim.treesitter.get_node_text(tree:root(), buf):gsub("^%s+", "")
          seen[#seen + 1] = first:sub(1, 9)
        end
        seen[lt:lang()] = true
      end)
      return { has_markdown = seen.markdown == true, first = seen[1] or "" }
    end)()
  ]])
  expect.equality(langs.has_markdown, true)
  -- The `#offset!` must have stripped `/-!`, or markdown sees it as text.
  expect.equality(langs.first:find("/%-!") == nil, true)
  expect.equality(langs.first:find("# Heading", 1, true) ~= nil, true)
end

-- Auto-start is deliberately narrow: the generated book renders on open, and
-- every other Lean buffer -- Mathlib's docstrings included -- waits for \p.
T["lean prose"]["auto-starts only in the generated book"] = function()
  local r = child.lua_get([[
    (function()
      local prose = require("config.lean.prose")
      local function at(name)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, name)
        return prose.should_auto(buf)
      end
      return {
        book = at("/Users/dan/LeanCourse/MathematicsInLean/MILbook/C03_Logic/S02_X.lean"),
        exercises = at("/Users/dan/LeanCourse/MathematicsInLean/MIL/C03_Logic/S02_X.lean"),
        mathlib = at("/Users/dan/mathlib4/Mathlib/Order/Filter/Basic.lean"),
      }
    end)()
  ]])
  expect.equality(r.book, true)
  expect.equality(r.exercises, false)
  expect.equality(r.mathlib, false)
end

T["lean prose"]["markview knows about the lean filetype"] = function()
  -- Without this markview's refresh autocmds bail out on a lean buffer, so an
  -- attached buffer would draw once and then never update.
  local fts = child.lua_get([[
    (function()
      local ok, spec = pcall(require, "markview.spec")
      if not ok then return {} end
      return spec.get({ "preview", "filetypes" }, { fallback = {}, ignore_enable = true })
    end)()
  ]])
  expect.equality(vim.tbl_contains(fts, "lean"), true)
end

return T
