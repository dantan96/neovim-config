-- lua/config/lean/prose.lua — render the Markdown inside `/-! -/` blocks.
--
-- Mathematics in Lean ships generated: upstream keeps prose and code in one
-- literate file and splits them, so the exercise files arrive with the prose
-- stripped and reading the book means a browser tab (which is what
-- <LocalLeader>b exists for). `tools/mil-literate/mklit.py` in the leanSetup
-- repo puts the prose back as `/-! -/` module docs holding Markdown; this
-- renders it in place.
--
-- WHY A TREE-SITTER GRAMMAR AT ALL, given everything else here comes from the
-- server: markdown-inside-docstrings is the one capability an LSP structurally
-- cannot express — semanticTokens has no way to say "this range is markdown".
--
-- WHY NOT `Julian/tree-sitter-lean`: it recovers 82.3% of docstrings over a
-- 150-file Mathlib sample (only 13.6% of Mathlib files parse without an ERROR
-- node at all), because Lean's syntax is user-extensible and no fixed grammar
-- can keep up. `leantiny` — comments and strings only, every other byte an
-- opaque token — recovers 99.6%, parses 8311/8311 Mathlib files clean, and is
-- 8.8 KB against 7.5 MB. research/08-treesitter-ceiling.md, Results 0 and 6.
--
-- WHAT THIS DOES NOT DO: it never calls vim.treesitter.start(), so no
-- tree-sitter highlight group is ever applied to a Lean buffer and the palette
-- is untouched. The parser exists solely so the injection query can hand
-- markview a `markdown` tree. Verify with <leader>K on a code cell: the winning
-- group must still be the LSP one at priority 125/129.

local M = {}

local LANG = "leantiny"

---Is the leantiny parser actually loadable?
---@return boolean
local function have_parser()
  return pcall(vim.treesitter.language.add, LANG)
end

---Register leantiny as the parser for Lean buffers.
---
---markview resolves the buffer's parser with `get_parser(buf)` and no explicit
---language, which goes through the filetype, so the registration is what makes
---the injected markdown tree reachable at all.
local registered = false
local function ensure_registered()
  if registered then
    return true
  end
  if not have_parser() then
    return false
  end
  vim.treesitter.language.register(LANG, "lean")
  registered = true
  return true
end

---@param buf integer?
---@return boolean
function M.is_on(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return vim.b[buf].lean_prose_on == true
end

---Start rendering prose in this buffer.
---@param buf integer?
function M.attach(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if M.is_on(buf) then
    return
  end
  if not ensure_registered() then
    vim.notify("lean prose: the leantiny parser is not installed", vim.log.levels.WARN)
    return
  end

  local ok = pcall(vim.treesitter.get_parser, buf, LANG)
  if not ok then
    vim.notify("lean prose: could not parse this buffer", vim.log.levels.WARN)
    return
  end

  -- DELIBERATELY NOT vim.treesitter.start().
  --
  -- It looked like a free win — leantiny ships no highlights.scm, so the only
  -- captures that could fire come from the injected markdown trees, and prose
  -- would gain headings, code spans and spell/nospell regions while code gained
  -- nothing. Measured, it is a net loss: starting the tree-sitter highlighter
  -- disables the vim syntax layer for the WHOLE buffer, and Lean's syntax file
  -- is what colours everything the server does not tokenise. On
  -- `example : ∃ x : ℝ, ...` the cell at column 10 went from
  -- `syntax=[leanBinderSymbol]` to nothing, while prose gained only
  -- `treesitter=[spell(markdown)]`.
  --
  -- So the parser stays parse-only. markview draws the prose structure from
  -- extmarks either way (315 of them on C03S02), which is the part that
  -- matters, and code keeps both the LSP tokens at 125 and the syntax fallback.

  local mv_ok, mv = pcall(require, "markview.actions")
  if not mv_ok then
    vim.notify("lean prose: markview.nvim is not available", vim.log.levels.WARN)
    return
  end
  -- Call the Lua API directly: :Markview passes its argument as a string and
  -- markview's state.buf_safe() rejects non-number buffer ids silently.
  pcall(mv.attach, buf)
  vim.b[buf].lean_prose_on = true
end

---Stop rendering prose in this buffer.
---
---`lazy_only` skips the work when markview has not been loaded yet: markview is
---lazy-loaded from its `keys` spec, and requiring one of its modules is what
---triggers lazy.nvim to load it. Detaching unconditionally would therefore load
---the whole plugin just to tell it to do nothing, in every Lean buffer.
---@param buf integer?
---@param lazy_only boolean? only act if markview is already loaded
function M.detach(buf, lazy_only)
  buf = buf or vim.api.nvim_get_current_buf()
  if lazy_only and not package.loaded["markview"] then
    vim.b[buf].lean_prose_on = false
    return
  end
  local mv_ok, mv = pcall(require, "markview.actions")
  if mv_ok then
    pcall(mv.detach, buf)
  end
  vim.b[buf].lean_prose_on = false
end

---@param buf integer?
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if M.is_on(buf) then
    M.detach(buf)
  else
    M.attach(buf)
  end
end

---Should this buffer render prose without being asked?
---
---Only the generated literate book does. A Mathlib file is full of `/--`
---docstrings that would also render, which is a real win but a large uninvited
---change to every Lean buffer, so it stays behind the toggle.
---@param buf integer?
---@return boolean
function M.should_auto(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  return name:find("/MILbook/", 1, true) ~= nil
end

return M
