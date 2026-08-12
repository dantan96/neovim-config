-- tests/test_lean_namespaces.lua — namespace components, module paths and the
-- keyword split (lua/config/lean/namespace_hl.lua + after/syntax/lean.vim).
--
-- WHAT THESE TESTS CAN AND CANNOT SEE, stated up front because getting this
-- wrong here is the classic way to ship a green suite that cannot fail:
--
--   * The SYNTAX layer works headless. `:syntax` runs whether or not anything
--     is drawn, so `synstack()` is a real observation and the path cases below
--     are genuine.
--   * SEMANTIC TOKENS DO NOT. A headless Neovim creates no extmarks for them
--     at all (GOTCHAS A1) — the highlighter builds them from a decoration
--     provider's `on_win`, and there is no window being drawn. So there is no
--     point asserting here that the `@lean.ns.prefix` mark lands; such an
--     assertion could only ever pass vacuously.
--
--     What is testable, and is what these cases do, is the DECISION: `marks()`
--     is pure — token in, list of (start, end, group) out — so every rule
--     about which tokens get split and which are refused is checked directly,
--     and the rendered-cell half is verified out of band with
--     docs/lean-highlighting/tools/hl_cells.sh against a pty-hosted TUI.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()
local tmp_dir

T["lean namespaces"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      -- No lakefile, so nothing elaborates and these cases measure the config
      -- rather than the server. Every line here is one the syntax rules must
      -- get right, including the two the old lookbehind got wrong.
      vim.fn.writefile({
        "import Mathlib.Order.Filter.Basic",
        "open Function Set Order",
        "open scoped Classical",
        "universe u v",
        "namespace MIL.C05.S02",
        "variable {α : Type u}",
        "theorem t (n : Nat) : n.succ ≠ Nat.zero := Nat.succ_ne_zero n",
        "def d : Nat := fun x => x",
        "end MIL.C05.S02",
        "import Foo.Bar -- trailing comment",
      }, tmp_dir .. "/paths.lean")
      child.lua(string.format("vim.cmd.edit(%q)", tmp_dir .. "/paths.lean"))
      child.lua("vim.wait(500)")
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

local NS = T["lean namespaces"]

--- The innermost syntax group at a 1-based line / 0-based byte column.
local function syn_at(lnum, col)
  return child.lua_get(string.format(
    [[(function()
      local st = vim.fn.synstack(%d, %d)
      if #st == 0 then return "" end
      return vim.fn.synIDattr(st[#st], "name")
    end)()]],
    lnum,
    col + 1
  ))
end

-- ── the syntax layer: module paths ─────────────────────────────────────

NS["path: prefix, separator and final component are three groups"] = function()
  -- import Mathlib.Order.Filter.Basic
  --        ^7      ^14 ^15         ^28
  expect.equality(syn_at(1, 0), "leanModuleKeyword")
  expect.equality(syn_at(1, 7), "leanPathPrefix") -- Mathlib
  expect.equality(syn_at(1, 14), "leanPathDot")
  expect.equality(syn_at(1, 15), "leanPathPrefix") -- Order
  expect.equality(syn_at(1, 28), "leanPathFinal") -- Basic
end

NS["path: every name in a multi-name open is reached"] = function()
  -- The old lookbehind rule matched only the FIRST name, so `Set` and `Order`
  -- fell through to leanConstant and rendered as lemma references. Measured on
  -- rendered cells before this change: Function #cdd6f4, Set #89b4fa.
  -- open Function Set Order
  --      ^5       ^14 ^18
  expect.equality(syn_at(2, 5), "leanPathFinal")
  expect.equality(syn_at(2, 14), "leanPathFinal")
  expect.equality(syn_at(2, 18), "leanPathFinal")
end

NS["path: `scoped` is a qualifier, not a path component"] = function()
  -- open scoped Classical
  --      ^5     ^12
  expect.equality(syn_at(3, 5), "leanPathQual")
  expect.equality(syn_at(3, 12), "leanPathFinal")
end

NS["path: universe and section names are final components"] = function()
  expect.equality(syn_at(4, 0), "leanModuleKeyword") -- universe
  expect.equality(syn_at(4, 9), "leanPathFinal") -- u
  expect.equality(syn_at(4, 11), "leanPathFinal") -- v
end

NS["path: a dotted namespace splits, on `namespace` and on `end` alike"] = function()
  -- namespace MIL.C05.S02      end MIL.C05.S02
  expect.equality(syn_at(5, 10), "leanPathPrefix") -- MIL
  expect.equality(syn_at(5, 13), "leanPathDot")
  expect.equality(syn_at(5, 18), "leanPathFinal") -- S02
  expect.equality(syn_at(9, 4), "leanPathPrefix") -- MIL
  expect.equality(syn_at(9, 12), "leanPathFinal") -- S02
end

NS["path: `variable` does NOT open a path region"] = function()
  -- Its argument is a binder list, not a path. `variable {α : Type u}` must
  -- leave `α` to the semantic layer rather than calling it a module name.
  expect.equality(syn_at(6, 0), "leanModuleKeyword")
  expect.no_equality(syn_at(6, 10), "leanPathFinal")
end

NS["path: a trailing comment is not eaten as a component"] = function()
  -- `-` is in no identifier, but it IS in the obvious negated character class,
  -- and leanPathFinal is defined after leanComment so it would win the tie.
  -- import Foo.Bar -- trailing comment
  --                ^15
  expect.equality(syn_at(10, 15), "leanComment")
end

NS["path: a term-position identifier is still a constant reference"] = function()
  -- The region must not leak past its line, and nothing outside a command
  -- line may be treated as a path.
  -- byte 45, not 43: `≠` is three bytes and synstack() takes byte columns.
  expect.equality(syn_at(7, 45), "leanConstant") -- Nat.succ_ne_zero
end

-- ── the syntax layer: binder keywords ──────────────────────────────────

NS["binder keywords are separated from declaration keywords"] = function()
  expect.equality(syn_at(8, 0), "leanDeclaration") -- def, left to mauve
  expect.equality(syn_at(8, 15), "leanBinderKeyword") -- fun
end

NS["`∀ ∃ λ` are binder keywords and not operators"] = function()
  -- The server emits NO token for these at all, so this rule is the only
  -- thing that reaches them. Before the change they were leanOp -> Operator,
  -- sharing sky #89dceb with type variables.
  local got = child.lua_get([[(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "theorem q : ∀ n, ∃ m, n = m := λ n => rfl" })
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lean"
    local out = {}
    for _, needle in ipairs({ "∀", "∃", "λ" }) do
      local c = vim.fn.stridx(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], needle)
      local st = vim.fn.synstack(1, c + 1)
      out[needle] = #st > 0 and vim.fn.synIDattr(st[#st], "name") or ""
    end
    return out
  end)()]])
  expect.equality(got["∀"], "leanBinderKeyword")
  expect.equality(got["∃"], "leanBinderKeyword")
  expect.equality(got["λ"], "leanBinderKeyword")
end

-- ── the token handler: which tokens get split, and which are refused ───

local function marks(token, text)
  return child.lua_get(string.format(
    [[require("config.lean.namespace_hl").marks(%s, %q)]],
    vim.inspect(token):gsub("%s+", " "),
    text
  ))
end

NS["split: a dotted reference yields prefix and separator, never the final"] = function()
  expect.equality(
    marks({ type = "theorem", start_col = 2, end_col = 14, modifiers = {} }, "Nat.succ.inj"),
    {
      { 2, 5, "@lean.ns.prefix" },
      { 5, 6, "@lean.ns.dot" },
      { 6, 10, "@lean.ns.prefix" },
      { 10, 11, "@lean.ns.dot" },
    }
  )
end

NS["split: an unqualified name is left completely alone"] = function()
  expect.equality(marks({ type = "theorem", start_col = 0, end_col = 3, modifiers = {} }, "foo"), {})
end

NS["split: a guillemet-quoted name is refused"] = function()
  -- `«foo.bar»` is ONE identifier whose name contains a dot. Splitting it
  -- would paint half a name as a namespace that does not exist.
  expect.equality(
    marks({ type = "function", start_col = 0, end_col = 11, modifiers = {} }, "«foo.bar»"),
    {}
  )
end

NS["split: a local is refused before its text is even read"] = function()
  expect.equality(
    marks({ type = "variable", start_col = 0, end_col = 5, modifiers = { ["local"] = true } }, "a.b"),
    {}
  )
end

NS["split: an axiom keeps its whole-name underline"] = function()
  -- GOTCHAS B4: one underline style per cell. highlights.lua underlines an
  -- axiom across the whole token; splitting the underline mid-name would
  -- degrade the stronger signal. `Classical.choice` is the real case.
  expect.equality(
    marks({ type = "axiom", start_col = 0, end_col = 16, modifiers = { axiom = true } }, "Classical.choice"),
    {}
  )
  expect.equality(
    marks({ type = "variable", start_col = 0, end_col = 5, modifiers = { autoImplicit = true } }, "a.b"),
    {}
  )
end

NS["keyword: only the listed words move, and the whole token moves"] = function()
  expect.equality(
    marks({ type = "keyword", start_col = 0, end_col = 6, modifiers = {} }, "import"),
    { { 0, 6, "@lean.path.keyword" } }
  )
  expect.equality(
    marks({ type = "keyword", start_col = 4, end_col = 7, modifiers = {} }, "fun"),
    { { 4, 7, "@lean.binder.keyword" } }
  )
end

NS["keyword: declaration keywords, sorts and tactics are refused"] = function()
  -- `theorem`/`def` keep mauve by design. `Type*` and `ℕ` are notation atoms
  -- the server also calls `keyword` (GOTCHAS B7). `rw`/`exact` arrive as type
  -- `tactic` on the patched server but as `keyword` on the stock one — this
  -- module must be correct under both, which it is because it dispatches on
  -- the text and they are not in the list.
  for _, kw in ipairs({ "theorem", "def", "instance", "structure", "class", "Type*", "ℕ", "by", "simp", "_", "rw", "exact" }) do
    expect.equality(marks({ type = "keyword", start_col = 0, end_col = #kw, modifiers = {} }, kw), {})
  end
end

-- ── groups, links and the priority contract ────────────────────────────

NS["priority sits exactly one above highlights.lua"] = function()
  local got = child.lua_get([[(function()
    return {
      ours = require("config.lean.namespace_hl").priority(),
      theirs = vim.hl.priorities.semantic_tokens + 3,
      builtin_top = vim.hl.priorities.semantic_tokens + 2,
    }
  end)()]])
  expect.equality(got.ours, 129)
  expect.equality(got.ours, got.theirs + 1)
  expect.equality(got.ours > got.builtin_top, true)
end

NS["every group is a complete spec with a foreground, bar the one that must not have one"] = function()
  -- GOTCHAS B1: a partial child definition renders colourless. The single
  -- deliberate exception is @lean.ns.prefix, which sets only underdotted+sp so
  -- that highlights.lua's foreground composes through it.
  local got = child.lua_get([[(function()
    local m = require("config.lean.namespace_hl")
    local out = {}
    for name in pairs(m.groups()) do
      local hl = vim.api.nvim_get_hl(0, { name = name })
      out[name] = hl.fg ~= nil
    end
    return out
  end)()]])
  expect.equality(got["@lean.ns.prefix"], false)
  for _, name in ipairs({
    "@lean.path.keyword",
    "@lean.path.prefix",
    "@lean.path.dot",
    "@lean.path.final",
    "@lean.binder.keyword",
    "@lean.ns.dot",
  }) do
    expect.equality(name .. "=" .. tostring(got[name]), name .. "=true")
  end
end

NS["the groups survive a colorscheme change"] = function()
  -- `:colorscheme` runs `:hi clear`, which drops definitions AND links, and
  -- the syntax file is not re-sourced. Without the ColorScheme autocmd every
  -- path component would go colourless the first time the theme is reloaded.
  local got = child.lua_get([[(function()
    local before = vim.api.nvim_get_hl(0, { name = "@lean.path.final" }).fg
    vim.cmd("colorscheme " .. (vim.g.colors_name or "default"))
    vim.wait(100)
    return {
      fg = vim.api.nvim_get_hl(0, { name = "@lean.path.final" }).fg,
      before = before,
      link = vim.api.nvim_get_hl(0, { name = "leanPathFinal", link = true }).link,
    }
  end)()]])
  expect.equality(got.fg, got.before)
  expect.equality(got.link, "@lean.path.final")
end

NS["the palette is hand-picked, not derived"] = function()
  -- Named explicitly so that a future "just blend it a bit" edit has to delete
  -- an assertion rather than slip through. Dan's words: "FUCK any blending."
  expect.equality(child.lua_get([[require("config.lean.namespace_hl").palette]]), {
    brass = "#e5b567",
    flamingo = "#f2cdcd",
    slate = "#708090",
    olive = "#b8bb26",
  })
end

NS["@lsp.type.keyword.lean is never touched"] = function()
  -- Nineteen keyword atoms ride on that group, including every tactic on a
  -- stock toolchain. Clearing or restyling it would strip them all.
  local got = child.lua_get([[(function()
    local m = require("config.lean.namespace_hl")
    for name in pairs(m.groups()) do
      if name:match("^@lsp") then return name end
    end
    for name in pairs(m.LINKS) do
      if name:match("^@lsp") then return name end
    end
    return "none"
  end)()]])
  expect.equality(got, "none")
end

return T
