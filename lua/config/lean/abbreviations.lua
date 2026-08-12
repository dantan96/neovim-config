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
-- Fixed by replacing `load` with one that reads the file from the plugin's own
-- directory and memoizes, falling back to upstream if that file is ever not
-- there. A fourth local patch to lean.nvim behaviour, in the same style as the
-- three in lua/plugins/lean.lua. Remove when upstream uses `getinfo(1)`.

local M = {}

---Read lean.nvim's abbreviation table from a path that does not depend on who
---is calling.
---@param dir string lean.nvim's plugin directory
local function patch_load(dir)
  local ok, abbreviations = pcall(require, "lean.abbreviations")
  if not ok or type(abbreviations.load) ~= "function" then
    return
  end
  local path = vim.fs.joinpath(dir, "vscode-lean", "abbreviations.json")
  if not vim.uv.fs_stat(path) then
    return -- upstream moved it; leave their resolution alone
  end
  local original = abbreviations.load
  local memo
  abbreviations.load = function(...)
    if memo then
      return memo
    end
    local file = io.open(path, "r")
    if not file then
      return original(...)
    end
    local content = file:read("*a")
    file:close()
    -- `local` on BOTH names. Without it `ok` resolves to the `local ok` at
    -- the top of patch_load and this closure writes to it as an upvalue on
    -- every call -- an accidental shared write inside a memoizing patch.
    -- Benign as written (that `ok` is read once before the closure can run,
    -- and here it is written then read immediately), but nothing enforces
    -- either of those, and no linter flags it.
    -- `decoded_ok`, not `ok`: `local ok` here would shadow patch_load's own
    -- `ok` (line 83). Declaring it local was the fix for an accidental
    -- upvalue write; renaming keeps that without the shadowing.
    local decoded_ok, decoded = pcall(vim.json.decode, content)
    if not decoded_ok then
      return original(...)
    end
    memo = decoded
    return memo
  end
end

---@return string|nil dir lean.nvim's plugin directory, if lazy knows it
local function plugin_dir()
  local ok, lazy_config = pcall(require, "lazy.core.config")
  local spec = ok and lazy_config.plugins["lean.nvim"]
  return spec and spec.dir or nil
end

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
  local dir = plugin_dir()
  if dir then
    patch_load(dir)
  end

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
