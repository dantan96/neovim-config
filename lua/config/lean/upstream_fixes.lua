-- lua/config/lean/upstream_fixes.lua — the three lean.nvim defects this
-- config used to patch from the outside, kept alive for machines without the
-- fork.
--
-- ── Why this file exists ───────────────────────────────────────────────────
--
-- Until 2026-08-13 lua/plugins/lean.lua carried three monkey-patches to
-- lean.nvim behaviour: a Loogle nil-crash wrapper, a telescope finder wrapper,
-- and a satellite `winbuf_pred` shim. All three are now REAL IN-TREE FIXES in
-- the local fork (decisions.md D15; the fork's FORK-CHANGES.md M1–M3), where
-- the actual defect can be repaired instead of the symptom wrapped.
--
-- Deleting them from here would have been a silent regression on WorkBox and
-- main, which share this tree through chezmoi and have no fork — the Loogle
-- one especially, since it exists because of a crash that fires on nearly
-- every keystroke in `:Telescope loogle`. So they are not deleted; they are
-- moved behind the fallback. `setup()` is a no-op when the fork is loaded and
-- is exactly today's behaviour when it is not.
--
-- Do not "improve" the code below. It is deliberately a verbatim carry-over of
-- what shipped, because its only job is to keep other machines at parity with
-- where they already were. The improvements live in the fork.

local fork = require("config.lean.fork")

local M = {}

-- ── 1 · satellite.nvim's winbuf_pred moved module ──────────────────────────
--
-- lean/satellite.lua:68 opens update() with
--
--     local pred = async.winbuf_pred(bufnr, winid)
--
-- but satellite moved winbuf_pred from `satellite.async` to `satellite.util`
-- in its commit fc9672c ("refactor: update async lib to newer conventions") —
-- its own diagnostic handler calls `util.winbuf_pred`
-- (handlers/diagnostic.lua:96). So the field is nil and every render throws:
--
--     vim.schedule callback: .../lean/satellite.lua:68:
--       attempt to call field 'winbuf_pred' (a nil value)
--
-- Measured that way, not guessed: the traceback appeared in :messages the
-- moment a buffer long enough to need a scrollbar was opened, and the
-- handler's mark count sat at 0 throughout. Restoring the name onto the module
-- table is enough — lean/satellite.lua holds `async` as an upvalue and indexes
-- the field at call time, so this reaches it whichever module loaded first.
-- Guarded, so it disappears the day upstream fixes it.
--
-- The one thing NOT restored is the early abort: `async.ipairs` now takes a
-- single argument, so the `pred` lean passes as a second one is ignored and
-- its loop runs to completion instead of bailing when the buffer changes
-- underneath it. Harmless — the marks are recomputed on the next render
-- anyway — and not something to paper over from here. The fork does restore
-- it, because in-tree the call site itself can change.
local function satellite_shim()
  local has_async, satellite_async = pcall(require, "satellite.async")
  if has_async and satellite_async.winbuf_pred == nil then
    local has_util, satellite_util = pcall(require, "satellite.util")
    if has_util and type(satellite_util.winbuf_pred) == "function" then
      satellite_async.winbuf_pred = satellite_util.winbuf_pred
    end
  end
end

-- ── 2 · lean.loogle.search returns nil where the finder expects a table ────
--
-- lean/loogle.lua's search() returns `nil, err` when Loogle rejects a query.
-- lean.nvim's telescope finder only turns that into `{}` when `#prompt > 4`;
-- for a shorter prompt both guard branches are skipped and it returns the nil
-- straight into telescope, which calls ipairs() on it:
--
--   finders.lua:144: bad argument #1 to 'ipairs' (table expected, got nil)
--
-- The finder runs per keystroke, so this fires as soon as you type a short
-- prefix Loogle cannot parse — i.e. almost immediately. Verified directly:
-- loogle.search("abc") returns nil plus "unknown identifier 'abc'", while
-- "Nat" and "List.map" return tables.
--
-- Wrapping search() rather than the finder keeps the fix to one function and
-- leaves the notify/empty behaviour for long prompts untouched. The pcall also
-- covers search()'s error() on a non-200 status, which would otherwise
-- propagate out of the finder.
local function loogle_search_wrapper()
  local ok, loogle = pcall(require, "lean.loogle")
  if not ok or type(loogle.search) ~= "function" then
    return false
  end
  local search = loogle.search
  loogle.search = function(...)
    local called, results, err = pcall(search, ...)
    if not called then
      return {}, tostring(results)
    end
    return results or {}, err
  end
  return true
end

-- ── 3 · the finder's own empty-prompt nil path ─────────────────────────────
--
-- The finder has a second nil path, and it is the one that actually fires:
-- `if not prompt or prompt == '' then return nil end`, hit the instant the
-- picker opens with an empty prompt. Wrapping search() cannot reach it, so
-- wrap the extension too and guarantee the finder it builds never hands
-- telescope a nil. new_dynamic is swapped only for the synchronous call that
-- constructs the picker, then restored.
local function loogle_finder_wrapper()
  local tok, telescope = pcall(require, "telescope")
  if not tok then
    return false
  end
  local eok, ext = pcall(function()
    return telescope.extensions.loogle
  end)
  if not eok or type(ext) ~= "table" or type(ext.loogle) ~= "function" then
    return false
  end
  local picker = ext.loogle
  ext.loogle = function(opts)
    local finders = require("telescope.finders")
    local new_dynamic = finders.new_dynamic
    finders.new_dynamic = function(o)
      local fn = o.fn
      o.fn = function(prompt)
        return fn(prompt) or {}
      end
      return new_dynamic(o)
    end
    local called, err = pcall(picker, opts)
    finders.new_dynamic = new_dynamic
    if not called then
      error(err)
    end
  end
  return true
end

---Reapply the three compatibility fixes, unless the fork already carries them.
---
---Returns the list of fixes actually applied, so a test can assert both
---branches rather than assuming one. On the fork this is always `{}`.
---@return string[] applied
function M.setup()
  if fork.enabled() then
    return {}
  end

  local applied = {}
  satellite_shim()
  applied[#applied + 1] = "satellite_winbuf_pred"
  if loogle_search_wrapper() then
    applied[#applied + 1] = "loogle_search"
  end
  if loogle_finder_wrapper() then
    applied[#applied + 1] = "loogle_finder"
  end
  return applied
end

return M
