-- lua/config/lean/messages.lua — a whole-file diagnostic census.
--
-- Parity audit #1 ("All Messages", the cheap phase) and #37 (Problems view).
--
-- lean.nvim's infoview renders only the diagnostics on the CURRENT LINE
-- (components.lua:151-154), so the only way to learn the shape of a file's
-- errors is to walk the cursor through it. The MIL question this answers is
-- constant and specific: an exercise file has six `sorry`s and two real
-- errors, and "am I done?" is a count, not a scroll.
--
-- ── THE ROADMAP'S PRESCRIPTION IS WRONG AND SILENTLY SO ───────────────────
-- research/12-parity-roadmap.md §3 item 3 says the whole-FILE census is
-- `vim.diagnostic.setqflist({ bufnr = 0 })`. **`setqflist` has no `bufnr`
-- option and ignores the key.** `vim.diagnostic.setqflist.Opts` declares only
-- namespace/open/title/severity/format, and `set_list()` hardcodes
--
--     local bufnr        -- nil
--     if loclist then bufnr = api.nvim_win_get_buf(winnr) end
--     local diagnostics = get_diagnostics(bufnr, opts, false)
--
-- (runtime/lua/vim/diagnostic.lua:1004-1015). With `loclist == false` the
-- buffer filter is unconditionally nil, so the call gathers EVERY buffer.
-- Written as the roadmap has it, #1 would silently have shipped as #37 and
-- looked correct on a single-file test.
--
-- Hence two entry points, deliberately distinct, matching the two audit rows:
--
--   file()      -> LOCATION list, this buffer      #1
--   workspace() -> QUICKFIX list, every buffer     #37
--
-- The location list is also the better home for the file census on its own
-- merits: it is per-window, so it does not evict whatever is in the global
-- quickfix list. quicker.nvim decorates both — it loads on `ft == "qf"`,
-- which a location-list window also has, and its API takes a `loclist`
-- option throughout (quicker/init.lua:124, 144).

local M = {}

---Diagnostic counts for a buffer, worst-first.
---@param bufnr integer
---@return table {error=,warn=,info=,hint=,total=}
function M.counts(bufnr)
  local S = vim.diagnostic.severity
  local n = { error = 0, warn = 0, info = 0, hint = 0, total = 0 }
  local key = { [S.ERROR] = "error", [S.WARN] = "warn", [S.INFO] = "info", [S.HINT] = "hint" }
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    local k = key[d.severity]
    if k then
      n[k] = n[k] + 1
    end
    n.total = n.total + 1
  end
  return n
end

---The tally VS Code puts in the All Messages header (manual.md:276).
---@param n table as returned by M.counts
---@return string
function M.tally(n)
  if n.total == 0 then
    return "No messages"
  end
  local parts = {}
  for _, pair in ipairs({
    { "error", "error" },
    { "warn", "warning" },
    { "info", "info" },
    { "hint", "hint" },
  }) do
    local k, word = pair[1], pair[2]
    if n[k] > 0 then
      table.insert(parts, ("%d %s%s"):format(n[k], word, n[k] == 1 and "" or "s"))
    end
  end
  return table.concat(parts, ", ")
end

---Every diagnostic in THIS file, in a location list. Audit row #1.
function M.file()
  local bufnr = vim.api.nvim_get_current_buf()
  local n = M.counts(bufnr)
  if n.total == 0 then
    vim.notify("No messages in this file", vim.log.levels.INFO, { title = "Lean" })
    return
  end
  vim.diagnostic.setloclist({
    open = true,
    title = ("Lean messages — %s"):format(M.tally(n)),
  })
end

---Every diagnostic in every buffer, in the quickfix list. Audit row #37.
function M.workspace()
  vim.diagnostic.setqflist({ open = true, title = "Lean messages (all buffers)" })
end

return M
