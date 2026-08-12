-- tests/test_lean.lua — Lean 4 filetype support.
--
-- WHY THIS FILE EXISTS SEPARATELY, rather than a probe.lean entry in
-- tests/test_invariants.lua's PROBES list:
--
-- Opening a Lean buffer loads lean.nvim, which does two things the shared
-- invariants child cannot survive. It sets the GLOBAL 'breakat'
-- (" \t!@*-+;:,./?" -> " \t,="), which the option-snapshot case correctly
-- flags as a leak; and its autoopened infoview window carries 'winfixbuf',
-- so the next vim.cmd.edit() aborts with E1513 and takes the remaining
-- invariants cases with it. Both are lean.nvim's behaviour, not this
-- config's. Quarantining Lean in its own child keeps that blast radius to
-- this file while still testing the filetype.
--
-- The deprecation case below is the reason the file was written: lean.nvim
-- deprecated require("lean").setup in favour of vim.g.lean_config, and
-- because no test ever opened a .lean buffer, the config warned on every
-- Lean file for a while without anything catching it.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()
local tmp_dir

T["lean"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      -- No lakefile here on purpose: lean.nvim finds no project and starts
      -- no language server, so these cases test the config, not the server.
      vim.fn.writefile({
        "import Mathlib.Data.Real.Basic",
        "def dvalue : Nat := 3",
        "theorem tvalue (p : Prop) : p ∨ p → p := id",
        "  rw [← mul_assoc, Nat.succ_le_of_lt]",
      }, tmp_dir .. "/probe.lean")
      child.lua(string.format("vim.cmd.edit(%q)", tmp_dir .. "/probe.lean"))
      child.lua("vim.wait(2000)")
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

T["lean"]["filetype is detected"] = function()
  expect.equality(child.lua_get("vim.bo.filetype"), "lean")
end

-- The regression this file was created for. init.lua's vim.deprecate override
-- silences plugin-originated warnings, and snacks.notifier owns vim.notify, so
-- scan both sinks — same approach as test_invariants.
T["lean"]["no deprecation warnings from opening a Lean buffer"] = function()
  local hits = child.lua_get([[(function()
    local out = {}
    local msgs = vim.fn.execute("messages"):lower()
    if msgs:find("deprecat", 1, true) then
      table.insert(out, "messages")
    end
    local ok, hist = pcall(function() return Snacks.notifier.get_history() end)
    if ok and hist then
      for _, n in ipairs(hist) do
        local text = tostring(n.msg or ""):lower()
        if text:find("deprecat", 1, true) then
          table.insert(out, text:sub(1, 100))
        end
      end
    end
    return out
  end)()]])
  expect.equality(hits, {})
end

-- Configuring through lazy's `opts` is what triggered the deprecation: it makes
-- lazy call require("lean").setup(). The config must reach lean.nvim via the
-- global instead, and must actually be populated.
T["lean"]["configured via vim.g.lean_config, not setup()"] = function()
  expect.equality(child.lua_get("type(vim.g.lean_config)"), "table")
  expect.equality(child.lua_get("vim.g.lean_config.mappings"), true)
  expect.equality(child.lua_get("vim.g.lean_config.infoview.width"), 55)
  -- Pinned, because lean.nvim's default "auto" picks by aspect ratio and
  -- lands on a horizontal split in an ordinary ~100x50 window.
  expect.equality(child.lua_get("vim.g.lean_config.infoview.orientation"), "vertical")
end

-- textwidth=100 alone hard-wraps Lean terms mid-expression, because the global
-- formatoptions is "tcqj". The ftplugin must drop `t`.
T["lean"]["ftplugin: mathlib style without auto-wrap"] = function()
  expect.equality(child.lua_get("vim.bo.textwidth"), 100)
  expect.equality(child.lua_get("vim.bo.shiftwidth"), 2)
  expect.equality(child.lua_get("vim.bo.expandtab"), true)
  expect.equality(child.lua_get([[vim.bo.formatoptions:find("t") ~= nil]]), false)
  -- textwidth governs `gq` only. No colorcolumn: 100 is mathlib's contribution
  -- guideline, not a rule worth a permanent ruler competing with the infoview
  -- for width.
  expect.equality(child.lua_get("vim.wo.colorcolumn"), "")
end

T["lean"]["ftplugin: apostrophe is a keyword character"] = function()
  expect.equality(
    child.lua_get([[vim.tbl_contains(vim.opt_local.iskeyword:get(), "'")]]),
    true
  )
end

-- Buffer-local because mini.operators owns the `gr` prefix globally, shadowing
-- Neovim's built-in grn/gra/grr LSP maps.
T["lean"]["config-owned buffer-local maps exist"] = new_set({
  parametrize = { { "\\?" }, { "\\n" }, { "\\a" }, { "\\f" }, { "\\b" } },
}, {
  test = function(lhs)
    local found = child.lua_get(string.format(
      [[(function()
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
          if m.lhs == %q then return true end
        end
        return false
      end)()]],
      lhs
    ))
    expect.equality(found, true)
  end,
})

T["lean"]["mini.clue trigger is registered for this buffer"] = function()
  expect.equality(
    child.lua_get([[(vim.b.miniclue_config or {}).triggers ~= nil]]),
    true
  )
end

-- \? reads this at press time; a rename would fail silently into the fallback.
T["lean"]["cheatsheet file exists"] = function()
  local path = H.cfg .. "/lean-cheatsheet.md"
  expect.equality(vim.uv.fs_stat(path) ~= nil, true)
end

-- ── after/syntax/lean.vim ──────────────────────────────────────────────
-- Lemma references are the one part of a proof nothing highlights: leanls
-- sends no semantic token for them and lean.nvim's syntax file has no rule
-- that reaches them. These pin the rule that claims them, and the two
-- exclusions it has to respect. Byte columns are found by search rather than
-- counted, because the probe lines contain multibyte operators.
--
-- NOTE this child has no language server (no lakefile in the temp dir), so
-- what is under test is the SYNTAX layer alone. In a live buffer the locals
-- are painted back over by @lsp.type.variable.lean, which is the whole reason
-- a rule this broad is safe; that half was verified in a pty-hosted TUI.
local function syntax_at(lnum, needle)
  return child.lua_get(string.format(
    [[(function()
      local line = vim.api.nvim_buf_get_lines(0, %d - 1, %d, false)[1] or ""
      local s = line:find(%q, 1, true)
      if not s then return "NOT FOUND" end
      return vim.fn.synIDattr(vim.fn.synID(%d, s, 1), "name")
    end)()]],
    lnum,
    lnum,
    needle,
    lnum
  ))
end

T["lean"]["lemma references are highlighted"] = new_set({
  parametrize = {
    { 4, "mul_assoc", "leanConstant" },
    -- Dotted names stay one item rather than fragmenting at the dot.
    { 4, "Nat.succ_le_of_lt", "leanConstant" },
    -- Declaration names keep lean.nvim's own group: the rule must lose to
    -- leanDeclaration's nextgroup, not shadow it.
    { 2, "dvalue", "leanDeclarationName" },
    { 3, "tvalue", "leanDeclarationName" },
    -- Numbers are defined earlier in lean.nvim's syntax file and would lose
    -- the tie to any rule starting with \w.
    { 2, "3", "leanNumber" },
    -- Module paths were plain text before and stay that way.
    { 1, "Mathlib.Data.Real.Basic", "leanModulePath" },
    -- Untouched: the stock keyword and sort groups, which this file no longer
    -- splits. Colours the user already had must not move.
    { 2, "def", "leanDeclaration" },
    { 3, "theorem", "leanDeclaration" },
    { 3, "Prop", "leanSort" },
    { 3, "∨", "leanOp" },
  },
}, {
  test = function(lnum, needle, group)
    expect.equality(syntax_at(lnum, needle), group)
  end,
})

-- ── infoview background ────────────────────────────────────────────────
-- Pure colour arithmetic, so it runs in the parent against a synthetic
-- colorscheme rather than needing a live infoview window. (Whether the
-- namespace actually lands on the window was checked directly instead: in a
-- pty-hosted TUI the leaninfo window reports a non-global hl namespace whose
-- Normal links to LeanInfoviewNormal.)
T["infoview background"] = new_set({
  hooks = {
    pre_case = function()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local func = vim.api.nvim_get_hl(0, { name = "Function" })
      MiniTest.finally(function()
        vim.api.nvim_set_hl(0, "Normal", normal)
        vim.api.nvim_set_hl(0, "Function", func)
        vim.api.nvim_set_hl(0, "LeanInfoviewNormal", {})
      end)
    end,
  },
})

T["infoview background"]["tints the colorscheme background"] = function()
  vim.api.nvim_set_hl(0, "Normal", { fg = 0xcdd6f4, bg = 0x151520 })
  vim.api.nvim_set_hl(0, "Function", { fg = 0x89b4fa })
  dofile(H.cfg .. "/lua/config/lean/infoview_hl.lua").refresh()
  -- 12% of catppuccin mocha's blue mixed into this config's base.
  expect.equality(vim.api.nvim_get_hl(0, { name = "LeanInfoviewNormal" }).bg, 0x23283a)
end

-- A transparent colorscheme has no background to tint, and inventing one would
-- paint over the terminal.
T["infoview background"]["leaves a transparent scheme alone"] = function()
  vim.api.nvim_set_hl(0, "LeanInfoviewNormal", {})
  vim.api.nvim_set_hl(0, "Normal", { fg = 0xcdd6f4 })
  dofile(H.cfg .. "/lua/config/lean/infoview_hl.lua").refresh()
  expect.equality(vim.api.nvim_get_hl(0, { name = "LeanInfoviewNormal" }).bg, nil)
end

-- ── \b book-page resolution ────────────────────────────────────────────
-- Pure path logic, so it runs against a fixture instead of a real MIL
-- checkout: no network, no browser, and no dependency on ~/LeanCourse
-- existing. Built to mirror MIL's real shape — chapter-per-HTML-page, a
-- solutions/ subdirectory, and a section whose anchor is missing.
T["book"] = new_set()

local function book_fixture()
  local dir = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  vim.fn.mkdir(dir .. "/MIL/C02_Basics/solutions", "p")
  vim.fn.mkdir(dir .. "/html", "p")
  vim.fn.writefile({ "" }, dir .. "/lakefile.toml")
  for _, f in ipairs({
    "/MIL/C02_Basics/S01_Calculating.lean",
    "/MIL/C02_Basics/S09_Missing_Anchor.lean",
    "/MIL/C02_Basics/scratchpad.lean",
    "/MIL/C02_Basics/solutions/Solutions_S01_Calculating.lean",
    "/MIL/Common.lean",
  }) do
    vim.fn.writefile({ "" }, dir .. f)
  end
  vim.fn.writefile(
    { '<section id="basics">', '<section id="calculating">' },
    dir .. "/html/C02_Basics.html"
  )
  return dir
end

T["book"]["resolves section, solutions, fallback and non-sections"] = function()
  local dir = book_fixture()
  local book = dofile(H.cfg .. "/lua/config/lean/book.lua")
  local function target(rel)
    local url, err = book.target(dir .. rel)
    return url and url:gsub(".*/html/", "html/") or ("ERR: " .. tostring(err))
  end

  -- section file -> anchored
  expect.equality(
    target("/MIL/C02_Basics/S01_Calculating.lean"),
    "html/C02_Basics.html#calculating"
  )
  -- solutions live a level deeper but share the section's anchor
  expect.equality(
    target("/MIL/C02_Basics/solutions/Solutions_S01_Calculating.lean"),
    "html/C02_Basics.html#calculating"
  )
  -- derived anchor absent from the page -> chapter page, no dead fragment
  expect.equality(
    target("/MIL/C02_Basics/S09_Missing_Anchor.lean"),
    "html/C02_Basics.html"
  )
  -- not a section at all
  expect.equality(
    target("/MIL/C02_Basics/scratchpad.lean"),
    "html/C02_Basics.html"
  )
  -- outside any chapter directory -> declines, with a reason
  expect.equality(target("/MIL/Common.lean"):match("^ERR:") ~= nil, true)
end

T["book"]["declines quietly when a project has no html build"] = function()
  local dir = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  vim.fn.mkdir(dir .. "/MIL/C01_Intro", "p")
  vim.fn.writefile({ "" }, dir .. "/lakefile.toml")
  vim.fn.writefile({ "" }, dir .. "/MIL/C01_Intro/S01_Thing.lean")
  local book = dofile(H.cfg .. "/lua/config/lean/book.lua")
  local url, err = book.target(dir .. "/MIL/C01_Intro/S01_Thing.lean")
  expect.equality(url, nil)
  expect.equality(err:find("no rendered page") ~= nil, true)
end

return T
