-- lua/config/lean/abbreviations.lua — Lean unicode input outside Lean buffers,
-- and one upstream bug that makes `\la` throw.
--
-- Two things, both about lean.nvim's abbreviation table. Parity audit #40
-- (unicode input in the search/query field) and #44/#46 (the symbol picker).
--
-- ══ 1 · `\to` in a telescope prompt ═══════════════════════════════════════
--
-- `\ll` (Loogle) and `\la` (the symbol picker) are bound, and you could not
-- type a Lean query into either: `\to` in the prompt inserted a literal
-- backslash. For MIL that bites on exactly the queries worth making —
-- `∀ x, x ∈ s`, `_ ∣ _`, `⁻¹`. The type-pattern queries that work
-- (`?a * ?b = ?b * ?a`) are the ASCII minority.
--
-- NOT `abbreviations.enable('TelescopePrompt')`, WHICH CANNOT WORK.
-- `enable(pattern)` creates three autocmds and passes the pattern straight
-- through (abbreviations.lua:341-352). None of `InsertCharPre`, `InsertLeave`
-- or `BufLeave` is filetype-matched, so Neovim matches the pattern against the
-- BUFFER NAME. Telescope's prompt buffer is created by the layout and never
-- named; `TelescopePrompt` is its *filetype*, set at
-- telescope.nvim/lua/telescope/pickers.lua:613. Three autocmds that can never
-- fire, failing silently and looking installed.
--
-- `abbreviations.init(bufnr)` (abbreviations.lua:319-338) creates the same
-- three callbacks BUFFER-SCOPED, sidestepping pattern matching entirely. It is
-- what lean.nvim's own ftplugin calls.
--
-- MEASURED IN A PTY-HOSTED TUI, not reasoned about — the audit named two
-- hazards and marked both `[UNVERIFIED — no editor run]`, and both are now
-- settled against `:Telescope buffers` and `:Telescope loogle` on MIL:
--
--   * Column arithmetic across the prompt PREFIX is correct. The prompt's
--     `> ` is part of the buffer line, and `convert()` writes through
--     extmark-derived absolute columns, so `\alpha`+space in the prompt gives
--     buffer `> α ` and telescope's own get_current_line() `α `, cursor at the
--     right byte. Hazard 2 does not materialise.
--   * `<Tab>` and `<CR>` are restored faithfully. During an open abbreviation
--     they carry lean.nvim's `convert()` rhs; the moment it closes they are
--     back to telescope's callbacks, and `<Tab>` toggles a selection again.
--     Hazard 1 is real and is the documented behaviour, not a break.
--   * `<Esc>` mid-abbreviation is safe: `InsertLeave` converts, the prompt
--     shows `α`, and `:messages` stays empty.
--
-- Gated on lean.nvim having actually loaded. Without the guard, opening any
-- telescope picker in any filetype would `require('lean.abbreviations')` and
-- so pull lean.nvim in through lazy's require hook. `lean.abbreviations` is
-- in package.loaded exactly once a Lean buffer has been visited, which is
-- also the right scope for the feature.
--
-- ══ 2 · `:Telescope lean_abbreviations` throws ════════════════════════════
--
-- `\la` has never worked. `abbreviations.load()` locates its JSON with
--
--     local this_dir = vim.fs.dirname(debug.getinfo(2, 'S').source:sub(2))
--     local path = vim.fs.joinpath(this_dir, '../../vscode-lean/abbreviations.json')
--
-- (abbreviations.lua:25-26) — `getinfo(2)` is the CALLER's frame, not this
-- function's. It happens to work for every caller inside `lua/lean/`, which is
-- all of them but one: the telescope extension lives at
-- `lua/telescope/_extensions/lean_abbreviations.lua`, so the relative walk
-- lands on `lua/vscode-lean/abbreviations.json`, which does not exist, and
-- load() error()s:
--
--     Unable to read abbreviations from ".../lua/telescope/_extensions/
--       ../../vscode-lean/abbreviations.json"
--
-- Reproduced in a pty-hosted TUI on MIL. Insert-mode expansion and `\\`
-- (reverse lookup) are unaffected, because their callers do live in
-- `lua/lean/` — which is why this survived a bind, a clue entry, a cheatsheet
-- row and three passing tests.
--
-- Fixed IN THE FORK (FORK-CHANGES.md M4), not here: `getinfo(2)` became
-- `getinfo(1)`. This file now only handles abbreviations in telescope prompts.

local M = {}

-- The `\la` crash fix USED to live here as a wrapper around
-- `abbreviations.load`. It is now a real in-tree fix in the fork
-- (FORK-CHANGES.md M4): `debug.getinfo(2)` -> `debug.getinfo(1)`, so the JSON
-- resolves from that function's own frame rather than its caller's.
--
-- Deliberately NOT kept as a fallback. A silent fallback is what let the
-- original bug survive: the keymap, the clue entry, the cheatsheet row and
-- three tests all reported `\la` as working while it threw on every press.
-- lua/config/lean/fork.lua notifies loudly if the fork is missing instead.


---Whether lean.nvim's abbreviation machinery is loaded and so safe to reach
---for without loading the plugin as a side effect.
---@return boolean
function M.available()
  return package.loaded["lean.abbreviations"] ~= nil
end

---Turn on Lean abbreviation expansion in one telescope prompt buffer.
---@param bufnr integer
---@return boolean whether it was enabled
function M.init_prompt(bufnr)
  if not M.available() then
    return false
  end
  local ok = pcall(function()
    require("lean.abbreviations").init(bufnr)
  end)
  return ok
end

---Called from lua/plugins/lean.lua's `config`, i.e. once lean.nvim loads.
function M.setup()

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LeanAbbreviationsInPrompts", { clear = true }),
    pattern = "TelescopePrompt",
    desc = "Lean unicode abbreviations in telescope prompts",
    callback = function(args)
      M.init_prompt(args.buf)
    end,
  })
end

return M
