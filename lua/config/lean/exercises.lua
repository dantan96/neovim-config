-- lua/config/lean/exercises.lua — work through MIL's exercises as exercises.
--
-- An MIL section is a book with holes in it. What turns the literate file into
-- a workbook is knowing where the holes are, how many are left, and — when you
-- are stuck — what the answer was.
--
-- WHERE "UNSOLVED" COMES FROM: the server's own `declaration uses \`sorry\``
-- warning, not a text search for `sorry`. That matters in both directions. A
-- `sorry` inside a comment or a string is not an exercise, and a declaration can
-- be unfinished in ways that do not spell `sorry` at all. The diagnostic is the
-- elaborator's own opinion, and it disappears the moment the proof is real — so
-- the count is live, not a guess.
--
-- Requires the server to have elaborated the file, and diagnostics arrive
-- incrementally (measured: 2 of the 5 on C03S02 were present immediately, all 5
-- after ~20s). Signs are therefore refreshed on DiagnosticChanged rather than
-- computed once.

local M = {}

local SIGN_NS = vim.api.nvim_create_namespace("lean_exercise_signs")

-- The server writes it with BACKTICKS: "declaration uses `sorry`". A constant
-- transcribed from memory as "declaration uses 'sorry'" matched nothing at all,
-- and the failure presented as "this file has no exercises" — a wrong answer
-- that looks like a legitimate one. Matching the parts keeps either quoting
-- working, so a change of style upstream degrades to matching, not to silence.
---@param message string?
---@return boolean
local function is_sorry(message)
  return type(message) == "string"
    and message:find("declaration uses", 1, true) ~= nil
    and message:find("sorry", 1, true) ~= nil
end

---Rows (0-indexed) of the declarations still carrying a `sorry`.
---@param buf integer?
---@return integer[]
function M.unsolved(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local rows, seen = {}, {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if is_sorry(d.message) and not seen[d.lnum] then
      seen[d.lnum] = true
      rows[#rows + 1] = d.lnum
    end
  end
  table.sort(rows)
  return rows
end

---Jump to the next (1) or previous (-1) unsolved exercise, wrapping.
---@param dir 1|-1
function M.jump(dir)
  local buf = vim.api.nvim_get_current_buf()
  local rows = M.unsolved(buf)
  if #rows == 0 then
    vim.notify("lean exercises: none left in this file", vim.log.levels.INFO)
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1] - 1
  local target
  if dir > 0 then
    for _, r in ipairs(rows) do
      if r > cur then
        target = r
        break
      end
    end
    target = target or rows[1]
  else
    for i = #rows, 1, -1 do
      if rows[i] < cur then
        target = rows[i]
        break
      end
    end
    target = target or rows[#rows]
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
  vim.cmd("normal! zz")
end

---"2 of 7 solved" for this file, or nil when nothing is known yet.
---@param buf integer?
---@return string|nil
function M.status(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local index = M.load_index(buf)
  local left = #M.unsolved(buf)
  if not index then
    return left > 0 and string.format("%d exercise%s left", left, left == 1 and "" or "s") or nil
  end
  local total = #(index.pairs or {})
  if total == 0 then
    return nil
  end
  return string.format("%d of %d solved", math.max(0, total - left), total)
end

---Put a sign against every unsolved exercise.
---@param buf integer?
function M.refresh_signs(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, SIGN_NS, 0, -1)
  if vim.b[buf].lean_exercise_signs == false then
    return
  end
  local last = vim.api.nvim_buf_line_count(buf)
  for _, row in ipairs(M.unsolved(buf)) do
    if row < last then
      vim.api.nvim_buf_set_extmark(buf, SIGN_NS, row, 0, {
        sign_text = "◇",
        sign_hl_group = "DiagnosticSignWarn",
        priority = 8,
      })
    end
  end
end

-- ── revealing the answer ──────────────────────────────────────────────────

local index_cache = {}

---Load `solutions-index.json` for this buffer's book, if there is one.
---@param buf integer?
---@return { root: string, pairs: table[] }|nil
function M.load_index(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  local found = vim.fs.find("solutions-index.json", { path = vim.fs.dirname(name), upward = true })[1]
  if not found then
    return nil
  end
  local stat = vim.uv.fs_stat(found)
  local cached = index_cache[found]
  if cached and stat and cached.mtime == stat.mtime.sec then
    return M.section_of(cached.data, found, name)
  end
  local ok, content = pcall(vim.fn.readfile, found)
  if not ok then
    return nil
  end
  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"))
  if not decoded_ok then
    return nil
  end
  index_cache[found] = { data = decoded, mtime = stat and stat.mtime.sec }
  return M.section_of(decoded, found, name)
end

---Pick this file's entry out of the whole-book index.
---@param data table
---@param index_path string
---@param buf_name string
---@return { root: string, pairs: table[] }|nil
function M.section_of(data, index_path, buf_name)
  local root = vim.fs.dirname(index_path)
  local rel = buf_name:sub(#root + 2)
  local entry = data[rel]
  if not entry then
    return nil
  end
  return { root = root, pairs = entry }
end

---A statement without its `:=` / `:= by` tail.
---@param s string
---@return string
local function normalize(s)
  return (s:gsub("%s*:=%s*by%s*$", ""):gsub("%s*:=%s*$", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

---The solution for the exercise the cursor is in.
---
---Found by searching UPWARD for a line that is a key in the index: the keys are
---exercise statements, so the nearest one above the cursor is the exercise you
---are inside. Line numbers would have been simpler and wrong — the reader's own
---edits move every line below the first thing they prove.
---@param buf integer?
---@return string[]|nil solution, string|nil key
function M.solution_here(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local index = M.load_index(buf)
  if not index then
    return nil, nil
  end
  local by_key, by_nkey = {}, {}
  for _, pair in ipairs(index.pairs) do
    by_key[pair.key] = pair.solution
    if pair.nkey then
      by_nkey[pair.nkey] = pair.solution
    end
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, row, false)
  for i = #lines, 1, -1 do
    -- Exact first; the exercise and its answer occasionally disagree on the
    -- proof tail alone, which is not a different exercise.
    local sol = by_key[lines[i]] or by_nkey[normalize(lines[i])]
    if sol then
      return sol, lines[i]
    end
  end
  return nil, nil
end

---Show the answer for the exercise under the cursor, in a float.
function M.reveal()
  local buf = vim.api.nvim_get_current_buf()
  local solution, key = M.solution_here(buf)
  if not solution then
    if not M.load_index(buf) then
      vim.notify(
        "lean exercises: no solutions-index.json above this file "
          .. "(generate the book with mklit.py to get one)",
        vim.log.levels.WARN
      )
    else
      -- MIL genuinely leaves 111 of its 220 exercises unanswered; this is the
      -- common, correct case, not a lookup failure.
      vim.notify("lean exercises: MIL records no solution for this one", vim.log.levels.INFO)
    end
    return
  end

  local float = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float, 0, -1, false, solution)
  vim.bo[float].filetype = "lean"
  vim.bo[float].modifiable = false

  local width = 0
  for _, l in ipairs(solution) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local win = vim.api.nvim_open_win(float, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.min(math.max(width + 2, 30), vim.o.columns - 10),
    height = math.min(#solution, 20),
    style = "minimal",
    border = "rounded",
    title = " solution ",
    title_pos = "left",
  })
  vim.wo[win].wrap = false
  local _ = key

  -- Dismiss on the next move, like a hover.
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
    once = true,
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

---Attach the live pieces (signs) to a buffer.
---@param buf integer?
function M.attach(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local group = vim.api.nvim_create_augroup("LeanExercises" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    buffer = buf,
    callback = function()
      M.refresh_signs(buf)
    end,
  })
  M.refresh_signs(buf)
end

return M
