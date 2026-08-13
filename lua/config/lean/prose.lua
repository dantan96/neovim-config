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
-- WHAT IT DOES TO THE PALETTE: nothing, and that is measured rather than
-- asserted. leantiny ships no highlights.scm, so the only captures that can
-- fire come from the injected markdown trees and none of them can reach code.
-- The highlighter is started (for emphasis, headings and spell regions, which
-- markview does not draw) and the vim syntax layer is switched back on
-- immediately afterwards, so all three layers coexist:
--
--   prose cell   treesitter=[spell(markdown)]              syntax=[leanBlockComment]
--   code col 0   semantic=[@lsp.type.keyword.lean@125]     syntax=[leanCommand]
--   code col 10                                            syntax=[leanBinderSymbol]
--
-- Verify with <leader>K on a code cell: the winning group must still be the LSP
-- one at priority 125/129.

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

-- ── the `/-!` and `-/` lines ──────────────────────────────────────────────
--
-- markview never sees them: the injection query offsets them out, so markdown
-- is handed the prose alone. That is right for parsing and leaves two rows of
-- syntax per block on screen, which is what stops it reading as a page.
--
-- `conceal_lines` (Neovim 0.11+) removes the row entirely rather than blanking
-- it, which is the difference between a hidden delimiter and a gap. markview
-- already sets `conceallevel = 3` on the windows it attaches, so there is
-- nothing to configure.

local NS = vim.api.nvim_create_namespace("lean_prose_delimiters")

---Hide the delimiter rows of every module doc comment in the buffer.
---
---Driven by the parser rather than by a line scan, so a `/-` inside prose
---cannot fool it. Only a row that is *nothing but* the delimiter is hidden:
---Mathlib's one-line `/-! # Title -/` form has content on the same row, and
---concealing it would take the content with it.
---@param buf integer
local function conceal_delimiters(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  if not M.is_on(buf) then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, LANG)
  if not ok or not parser then
    return
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    return
  end

  local q_ok, query = pcall(vim.treesitter.query.parse, LANG, "((module_doc_comment) @c)")
  if not q_ok then
    return
  end

  local last = vim.api.nvim_buf_line_count(buf)
  for _, node in query:iter_captures(trees[1]:root(), buf) do
    local start_row, _, end_row, _ = node:range()
    for _, row in ipairs({ start_row, end_row }) do
      if row < last then
        local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
        if line:match("^%s*/%-!%s*$") or line:match("^%s*%-/%s*$") then
          vim.api.nvim_buf_set_extmark(buf, NS, row, 0, { conceal_lines = "" })
        end
      end
    end
  end
end

M.conceal_delimiters = conceal_delimiters

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

  -- Highlight the injected markdown, then put the syntax layer back.
  --
  -- markview has no emphasis renderer, so `*converge*` can only be italicised
  -- by tree-sitter, and the same pass is what supplies heading colours and the
  -- spell/nospell split that turns the checker off inside `inner_mul_self_le`.
  -- The first attempt at this was abandoned because starting the highlighter
  -- blanks the vim syntax layer for the WHOLE buffer, and Lean's syntax file is
  -- what colours everything the server does not tokenise: column 10 of
  -- `example : ∃ x : ℝ, ...` lost `leanBinderSymbol` outright.
  --
  -- But that is a single assignment inside TSHighlighter.new
  -- ($VIMRUNTIME/lua/vim/treesitter/highlighter.lua: `vim.bo[bufnr].syntax = ''`),
  -- not a structural exclusion. Setting it back gives both layers: syntax
  -- underneath, tree-sitter captures at priority 100 on top, LSP above at 125.
  -- Nothing tree-sitter draws can reach code anyway, because leantiny ships no
  -- highlights.scm and only the injected markdown trees can capture.
  pcall(vim.treesitter.start, buf, LANG)
  if vim.bo[buf].syntax ~= "lean" then
    vim.bo[buf].syntax = "lean"
  end

  local mv_ok, mv = pcall(require, "markview.actions")
  if not mv_ok then
    vim.notify("lean prose: markview.nvim is not available", vim.log.levels.WARN)
    return
  end
  -- The flag goes up FIRST: markview's preview.condition reads it to decide
  -- whether this buffer may be attached and refreshed at all, so setting it
  -- afterwards would have the attach evaluate against `false`.
  vim.b[buf].lean_prose_on = true
  -- Call the Lua API directly: :Markview passes its argument as a string and
  -- markview's state.buf_safe() rejects non-number buffer ids silently.
  pcall(mv.attach, buf)

  -- Keep the concealed delimiters in step with edits. Own group per buffer so
  -- detaching removes exactly these autocmds and nothing else.
  local group = vim.api.nvim_create_augroup("LeanProse" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
    group = group,
    buffer = buf,
    callback = function()
      conceal_delimiters(buf)
    end,
  })
  conceal_delimiters(buf)
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
  pcall(vim.treesitter.stop, buf)
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].syntax ~= "lean" then
    vim.bo[buf].syntax = "lean"
  end
  pcall(vim.api.nvim_del_augroup_by_name, "LeanProse" .. buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  end
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
