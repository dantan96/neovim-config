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

NS["path: components are coloured by POSITION, cycling"] = function()
  -- import Mathlib.Order.Filter.Basic
  --        ^7      ^14 ^15         ^28
  -- `C{i}` is a component followed by a dot, `F{i}` the last one. The index
  -- is the component's POSITION in the path, which is the whole point of the
  -- rainbow: 1 red, 2 orange, 3 yellow, 4 green...
  expect.equality(syn_at(1, 0), "leanModuleKeyword")
  expect.equality(syn_at(1, 7), "leanPathC1") -- Mathlib
  expect.equality(syn_at(1, 14), "leanPathDot1")
  expect.equality(syn_at(1, 15), "leanPathC2") -- Order
  expect.equality(syn_at(1, 21), "leanPathC3") -- Filter
  expect.equality(syn_at(1, 28), "leanPathF4") -- Basic
end

NS["path: the position, not the text, decides the colour"] = function()
  -- The failure this guards is a "rainbow" that is really a lookup table of
  -- known namespace names — which would colour `Mathlib` red wherever it
  -- appeared and leave an unknown vendor path grey. Two paths with the SAME
  -- components in the OPPOSITE order must colour position-for-position
  -- identically. This is also the mechanism check for the nextgroup chain
  -- (GOTCHAS B9: a plausible syntax construction that silently paints
  -- nothing, while `:syntax list` looks perfect).
  local got = child.lua_get([[(function()
    -- Restore the shared child's buffer afterwards: every other case in this
    -- file reads `synstack()` from whatever is current, and a scratch buffer
    -- left in place makes six later cases fail for a reason that has nothing
    -- to do with them.
    local was = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "import Mathlib.Data.Real.Basic",
      "import Basic.Real.Data.Mathlib",
      "import A.B.C.D.E.F.G.H",
    })
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lean"
    local out = {}
    for l = 1, 3 do
      local line = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1]
      local row = {}
      for c = 8, #line do
        local st = vim.fn.synstack(l, c)
        local g = #st > 0 and vim.fn.synIDattr(st[#st], "name") or ""
        if g ~= row[#row] then row[#row + 1] = g end
      end
      out[l] = row
    end
    vim.api.nvim_set_current_buf(was)
    vim.api.nvim_buf_delete(buf, { force = true })
    return out
  end)()]])
  expect.equality(got[1], got[2])
  -- Non-vacuity: an empty or all-blank reading would compare equal to itself.
  expect.equality(got[1], {
    "leanPathC1", "leanPathDot1", "leanPathC2", "leanPathDot2",
    "leanPathC3", "leanPathDot3", "leanPathF4",
  })
  -- ...and the cycle wraps rather than running out at six.
  expect.equality(got[3], {
    "leanPathC1", "leanPathDot1", "leanPathC2", "leanPathDot2",
    "leanPathC3", "leanPathDot3", "leanPathC4", "leanPathDot4",
    "leanPathC5", "leanPathDot5", "leanPathC6", "leanPathDot6",
    "leanPathC1", "leanPathDot1", "leanPathF2",
  })
end

NS["path: every name in a multi-name open is reached"] = function()
  -- The old lookbehind rule matched only the FIRST name, so `Set` and `Order`
  -- fell through to leanConstant and rendered as lemma references. Measured on
  -- rendered cells before this change: Function #cdd6f4, Set #89b4fa.
  -- open Function Set Order
  --      ^5       ^14 ^18
  -- Each name restarts the cycle at position 1, so all three are `F1`.
  expect.equality(syn_at(2, 5), "leanPathF1")
  expect.equality(syn_at(2, 14), "leanPathF1")
  expect.equality(syn_at(2, 18), "leanPathF1")
end

NS["path: `scoped` is a qualifier, not a path component"] = function()
  -- open scoped Classical
  --      ^5     ^12
  expect.equality(syn_at(3, 5), "leanPathQual")
  expect.equality(syn_at(3, 12), "leanPathF1")
end

NS["path: universe and section names are final components"] = function()
  expect.equality(syn_at(4, 0), "leanModuleKeyword") -- universe
  expect.equality(syn_at(4, 9), "leanPathF1") -- u
  expect.equality(syn_at(4, 11), "leanPathF1") -- v
end

NS["path: a dotted namespace splits, on `namespace` and on `end` alike"] = function()
  -- namespace MIL.C05.S02      end MIL.C05.S02
  expect.equality(syn_at(5, 10), "leanPathC1") -- MIL
  expect.equality(syn_at(5, 13), "leanPathDot1")
  expect.equality(syn_at(5, 18), "leanPathF3") -- S02
  expect.equality(syn_at(9, 4), "leanPathC1") -- MIL
  expect.equality(syn_at(9, 12), "leanPathF3") -- S02
end

NS["path: `variable` does NOT open a path region"] = function()
  -- Its argument is a binder list, not a path. `variable {α : Type u}` must
  -- leave `α` to the semantic layer rather than calling it a module name.
  expect.equality(syn_at(6, 0), "leanModuleKeyword")
  expect.no_equality(syn_at(6, 10), "leanPathF1")
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

NS["`∀ ∃ λ ↦` are binder keywords and not operators"] = function()
  -- The server emits NO token for these at all, so this rule is the only
  -- thing that reaches them. Before the change they were leanOp -> Operator,
  -- sharing sky #89dceb with type variables.
  --
  -- `↦` IS THE THIRD RETUNE'S ADDITION and is a different case from the
  -- other three: it was in NO rule at all — lean.nvim's `leanOp` character
  -- class simply does not contain it — so it rendered as bare `Normal`.
  -- Dan: "`↦` renders uncoloured. It should not be." Non-vacuity for this
  -- one is easy to get wrong: asserting `leanBinderSymbol` would pass
  -- equally if `↦` had been added to `leanOp`, so the case also pins the
  -- RESOLVED colour below.
  local got = child.lua_get([[(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "theorem q : ∀ n, ∃ m, n = m := λ n ↦ rfl" })
    local was = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lean"
    local out = {}
    for _, needle in ipairs({ "∀", "∃", "λ", "↦" }) do
      local c = vim.fn.stridx(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], needle)
      local st = vim.fn.synstack(1, c + 1)
      out[needle] = #st > 0 and vim.fn.synIDattr(st[#st], "name") or ""
    end
    vim.api.nvim_set_current_buf(was)
    return out
  end)()]])
  -- Their own group, linked straight to @lean.binder.keyword rather than to
  -- the attribute-free floor: the server emits no token for them, so nothing
  -- can outrank them and nothing can leak. See the floor-group case.
  expect.equality(got["∀"], "leanBinderSymbol")
  expect.equality(got["∃"], "leanBinderSymbol")
  expect.equality(got["λ"], "leanBinderSymbol")
  expect.equality(got["↦"], "leanBinderSymbol")
  -- ...and the RESOLVED colour, which is what "not an operator" actually
  -- means. `leanOp` links to `Operator`, catppuccin's `#89dceb` sky; the
  -- binder group is `#ff1493` DeepPink. Asserting the group name alone
  -- would pass if `↦` had merely been added to lean.nvim's operator class,
  -- which is the plausible wrong fix.
  local resolved = child.lua_get([[(function()
    require("config.lean.namespace_hl").define()
    local h = vim.api.nvim_get_hl(0, { name = "leanBinderSymbol" })
    local t = vim.api.nvim_get_hl(0, { name = h.link or "leanBinderSymbol", link = false })
    local op = vim.api.nvim_get_hl(0, { name = "Operator", link = false })
    return { link = h.link, fg = t.fg and string.format("#%06x", t.fg) or "nil",
             op = op.fg and string.format("#%06x", op.fg) or "nil" }
  end)()]])
  expect.equality(resolved.link, "@lean.binder.keyword")
  expect.equality(resolved.fg, "#ff1493")
  expect.no_equality(resolved.fg, resolved.op)
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

NS["keyword: declaration keywords and tactics are refused"] = function()
  -- `theorem`/`def` keep plain mauve by design. `rw`/`exact` arrive as type
  -- `tactic` on the patched server but as `keyword` on the stock one — this
  -- module must be correct under both, which it is because it dispatches on
  -- the text and they are not in the list.
  for _, kw in ipairs({ "theorem", "def", "instance", "structure", "class", "by", "simp", "_", "rw", "exact" }) do
    expect.equality(marks({ type = "keyword", start_col = 0, end_col = #kw, modifiers = {} }, kw), {})
  end
end

NS["keyword: the sort atoms are claimed, and by TEXT"] = function()
  -- `Type*` and the blackboard-bold numerals are notation atoms the server
  -- calls `keyword` (GOTCHAS B7) — the grid cannot see them at all, so pink
  -- for them has to come from this layer. Dan asked for `Type*` hot pink and
  -- then for "`\R`, `\N`, etc to also be pink".
  for _, kw in ipairs({ "Type*", "Sort*", "Sort", "ℕ", "ℤ", "ℚ", "ℝ", "ℂ" }) do
    expect.equality(
      marks({ type = "keyword", start_col = 0, end_col = #kw, modifiers = {} }, kw),
      { { 0, #kw, "@lean.sort.atom" } }
    )
  end
  -- Dispatch is on TEXT, not on type: a `variable` token whose text happens
  -- to be `ℕ` is not a thing, but an identifier called `Sort` is, and it must
  -- not be claimed.
  expect.equality(
    marks({ type = "variable", start_col = 0, end_col = 4, modifiers = { ["local"] = true } }, "Sort"),
    {}
  )
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
    "@lean.path.floor",
    "@lean.path.dot",
    "@lean.path.c1",
    "@lean.path.f1",
    "@lean.path.c6",
    "@lean.path.f6",
    "@lean.sort.atom",
    "@lean.binder.keyword",
    "@lean.binder.floor",
    "@lean.ns.dot",
  }) do
    expect.equality(name .. "=" .. tostring(got[name]), name .. "=true")
  end
end

NS["the syntax-layer floor groups carry no attribute bits"] = function()
  -- Neovim composes PER ATTRIBUTE, so a `bold` set by a syntax group at
  -- priority 50 survives a semantic mark at 125 taking the foreground.
  -- Measured on rendered cells: `open scoped Classical` drew `scoped` as
  -- mauve-BOLD — mauve correctly from @lsp.type.keyword.lean, bold leaking up
  -- from this config — and a tactic-position `have` did the same. A group
  -- this layer links from a syn-keyword rule may therefore set `fg` and
  -- nothing else, or it silently edits the appearance of tokens
  -- highlights.lua owns.
  local got = child.lua_get([[(function()
    local m = require("config.lean.namespace_hl")
    local out = {}
    for syn, group in pairs(m.LINKS) do
      local hl = vim.api.nvim_get_hl(0, { name = group })
      local extra = {}
      for k, v in pairs(hl) do
        if k ~= "fg" and k ~= "cterm" and v then extra[#extra + 1] = k end
      end
      table.sort(extra)
      out[syn] = group .. ":" .. table.concat(extra, ",")
    end
    return out
  end)()]])
  -- `∀ ∃ λ` are the exception and are allowed the full treatment: measured,
  -- the server emits no token for them, so there is nothing to leak under.
  -- Not bold any more: binder keywords rejoined plain mauve in the retune,
  -- so there is no attribute left to carry. The exemption stands regardless.
  expect.equality(got.leanBinderSymbol, "@lean.binder.keyword:")
  expect.equality(got.leanModuleKeyword, "@lean.path.floor:")
  expect.equality(got.leanBinderKeyword, "@lean.binder.floor:")
  expect.equality(got.leanPathQual, "@lean.path.floor:")
  expect.equality(got.leanSort, "@lean.sort.atom:")
  -- The path components themselves keep theirs — also measured token-free.
  -- Only the FINAL component of a path is bold, at every position.
  for i = 1, 6 do
    expect.equality(got["leanPathC" .. i], "@lean.path.c" .. i .. ":")
    expect.equality(got["leanPathF" .. i], "@lean.path.f" .. i .. ":bold")
  end
end

NS["the rainbow's length is the same number in the palette and in the syntax file"] = function()
  -- `after/syntax/lean.vim` writes the cycle with a literal `range(1, 6)`,
  -- because a Vimscript file cannot read a Lua table. `M.LINKS` and
  -- `M.groups()` derive theirs from `#M.palette.rainbow`. Add a seventh hue
  -- and the group exists, the link exists, and NO SYNTAX RULE EVER MATCHES
  -- IT — `:hi @lean.path.c7` would look perfectly correct.
  --
  -- `hlexists` cannot see this: the LINKS loop defines the group either way.
  -- `:syntax list <name>` is the check, because it errors on an item that was
  -- never defined.
  local got = child.lua_get([[(function()
    local n = #require("config.lean.namespace_hl").palette.rainbow
    local function has(name)
      return pcall(vim.fn.execute, "syntax list " .. name)
    end
    local missing = {}
    for i = 1, n do
      if not has("leanPathC" .. i) then missing[#missing + 1] = "leanPathC" .. i end
      if not has("leanPathF" .. i) then missing[#missing + 1] = "leanPathF" .. i end
    end
    return { n = n, missing = missing, extra = has("leanPathC" .. (n + 1)) }
  end)()]])
  expect.equality(got.n, 6)
  expect.equality(got.missing, {})
  -- Non-vacuity: `has()` must be able to say no, or the loop above proves
  -- nothing at all.
  expect.equality(got.extra, false)
end

NS["leanSort is HARD-linked, or lean.nvim's own def-link wins"] = function()
  -- `Sort Prop Type` carry no semantic token, so the syntax layer is the only
  -- thing that reaches them — and lean.nvim already says
  -- `hi def link leanSort Type`. A second `hi def link` to an already-linked
  -- group does nothing at all: it would read as correct, `:hi leanSort` would
  -- show a link, and the link would be the plugin's.
  local got = child.lua_get([[(function()
    local m = require("config.lean.namespace_hl")
    m.define()
    return {
      link = vim.api.nvim_get_hl(0, { name = "leanSort", link = true }).link,
      hard = m.HARD.leanSort == true,
      -- and the ones that must stay `default`, so a user's own `:hi link`
      -- still survives
      qual = vim.api.nvim_get_hl(0, { name = "leanPathQual", link = true }).link,
    }
  end)()]])
  expect.equality(got.link, "@lean.sort.atom")
  expect.equality(got.hard, true)
  expect.equality(got.qual, "@lean.path.floor")
end

NS["the groups survive a colorscheme change"] = function()
  -- `:colorscheme` runs `:hi clear`, which drops definitions AND links, and
  -- the syntax file is not re-sourced. Without the ColorScheme autocmd every
  -- path component would go colourless the first time the theme is reloaded.
  local got = child.lua_get([[(function()
    local before = vim.api.nvim_get_hl(0, { name = "@lean.path.f4" }).fg
    vim.cmd("colorscheme " .. (vim.g.colors_name or "default"))
    vim.wait(100)
    return {
      fg = vim.api.nvim_get_hl(0, { name = "@lean.path.f4" }).fg,
      before = before,
      link = vim.api.nvim_get_hl(0, { name = "leanPathF4", link = true }).link,
    }
  end)()]])
  expect.equality(got.fg, got.before)
  expect.equality(got.link, "@lean.path.f4")
end

NS["nothing is painted under a derived Ghostty profile"] = function()
  -- themes.lua is `enabled = ghostty_profile.theme() == nil` and is what loads
  -- highlights.lua, so under GhosttyNu/Fish/Elvish/Xonsh there is no world x
  -- level grid. Four hand-picked hues over a foreign scheme with no grid under
  -- them is half a design.
  local got = child.lua_get([[(function()
    local m = require("config.lean.namespace_hl")
    local before = m.enabled()
    vim.g.ghostty_profile_theme_force = "kanagawa"
    package.loaded["config.ghostty_profile"] = nil
    local after = m.enabled()
    vim.g.ghostty_profile_theme_force = nil
    package.loaded["config.ghostty_profile"] = nil
    return { before = before, after = after, plain = m.enabled() }
  end)()]])
  expect.equality(got.before, true)
  expect.equality(got.after, false)
  expect.equality(got.plain, true)
end

NS["the palette is hand-picked, not derived"] = function()
  -- Named explicitly so that a future "just blend it a bit" edit has to delete
  -- an assertion rather than slip through. Dan's words: "FUCK any blending."
  expect.equality(child.lua_get([[require("config.lean.namespace_hl").palette]]), {
    mauve = "#cba6f7",
    slate = "#708090",
    hotpink = "#ff69b4",
    -- Third retune: the binder keywords take the DeepPink that
    -- `@lean.prop.former` vacated when the type level became one magenta
    -- family. Instructed by hex.
    deeppink = "#ff1493",
    brass = "#e5b567",
    -- Six catppuccin hues, cycling by POSITION. Spelled out rather than
    -- counted so that "rainbow" cannot quietly become three colours.
    rainbow = { "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#89b4fa", "#cba6f7" },
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
