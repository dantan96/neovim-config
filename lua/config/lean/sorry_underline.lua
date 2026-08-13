-- lua/config/lean/sorry_underline.lua — no squiggle under `sorry`.
--
-- Lean warns "declaration uses 'sorry'" on every incomplete proof, which in a
-- MIL exercise file is most of them. The warning itself is wanted — it is what
-- `\q`'s tally counts and what satellite plots down the scrollbar — but the
-- underline is pure noise: `sorry` already carries the `leanSorryLike`
-- background chip, which is the single most conspicuous thing in the buffer.
-- Two markers for one fact, on the token that needs it least.
--
-- WHY A HANDLER WRAPPER AND NOT A HIGHLIGHT CHANGE. Clearing
-- `DiagnosticUnderlineWarn` would take the squiggle off every warning in every
-- language — unused variables, deprecations, the lot. `vim.diagnostic.config`
-- can filter `underline` by SEVERITY but not by message, and `sorry` shares
-- its severity with warnings that genuinely want underlining. So the filter
-- has to happen where the diagnostic list is still visible, which is the
-- handler's `show`.
--
-- Only `underline` is wrapped. `virtual_text`, `signs` and the quickfix list
-- still see the diagnostic, so nothing that COUNTS sorries loses one.

local M = {}

--- Lean's exact wording, from `Init/Notation.lean:858`. Matched loosely on
--- `sorry` in quotes rather than the whole sentence, because the surrounding
--- text has changed across Lean versions and the quoted token has not.
local SORRY = "uses%s+['`]sorry['`]"

--- @param d table a diagnostic; only `.message` is read
--- @return boolean
local function is_sorry(d)
  return type(d.message) == "string" and d.message:find(SORRY) ~= nil
end

local wrapped = false

--- Idempotent: safe to call from `init` on every start.
function M.setup()
  if wrapped then
    return M
  end
  wrapped = true

  local underline = vim.diagnostic.handlers.underline
  local show = underline.show

  --- @param ns integer
  --- @param bufnr integer
  --- @param diagnostics table[]
  --- @param opts table|nil
  underline.show = function(ns, bufnr, diagnostics, opts)
    local keep = {}
    for _, d in ipairs(diagnostics or {}) do
      if not is_sorry(d) then
        keep[#keep + 1] = d
      end
    end
    -- Always call through, even when `keep` is empty: `show` is also what
    -- CLEARS stale extmarks for this namespace, so returning early would
    -- leave the previous underline painted after the sorry was filled in.
    return show(ns, bufnr, keep, opts)
  end

  return M
end

-- ── test surface ───────────────────────────────────────────────────────

--- @param message string
--- @return boolean
function M._is_sorry(message)
  return is_sorry({ message = message })
end

return M
