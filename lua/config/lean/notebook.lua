-- lua/config/lean/notebook.lua — read a literate Lean file like a notebook.
--
-- Navigation and cell views over the prose blocks that config.lean.prose
-- renders. A generated MILbook section runs to ~400 lines with twenty prose
-- blocks in it, and without this you scroll.
--
-- WHY CONCEAL AND NOT FOLDS, for the cell views: lean buffers already set
-- `foldmethod=expr` with `vim.lsp.foldexpr()` (after/ftplugin/lean.lua), so
-- folding ranges come from the Lean server. Taking over 'foldexpr' to hide
-- prose would mean wrapping or re-implementing that, and would put two sources
-- of folds in competition. `conceal_lines` is orthogonal — it composes with the
-- server's folds instead of replacing them, and it is the same mechanism
-- already proven for the `/-!` delimiters.

local prose = require("config.lean.prose")

local M = {}

local NS = vim.api.nvim_create_namespace("lean_notebook_view")

-- ── navigation ────────────────────────────────────────────────────────────

---Jump to the next or previous prose block.
---@param dir 1|-1
function M.jump_block(dir)
  local buf = vim.api.nvim_get_current_buf()
  local blocks = prose.blocks(buf)
  if #blocks == 0 then
    vim.notify("lean notebook: no prose in this buffer", vim.log.levels.INFO)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local target
  if dir > 0 then
    for _, b in ipairs(blocks) do
      if b.first > row then
        target = b
        break
      end
    end
  else
    for i = #blocks, 1, -1 do
      -- From inside a block, `[[` goes to the one before it, not to its own top.
      if blocks[i].last < row then
        target = blocks[i]
        break
      end
    end
  end
  if not target then
    vim.notify(
      dir > 0 and "lean notebook: last prose block" or "lean notebook: first prose block",
      vim.log.levels.INFO
    )
    return
  end

  -- Land on the first line with content, not on the concealed `/-!` row, which
  -- cannot hold the cursor visibly.
  local land = target.first
  local lines = vim.api.nvim_buf_get_lines(buf, target.first, target.last + 1, false)
  for i, l in ipairs(lines) do
    if l:match("%S") and not l:match("^%s*/%-!%s*$") then
      land = target.first + i - 1
      break
    end
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { land + 1, 0 })
  vim.cmd("normal! zz")
end

---The contents of this section: headings, prose blocks, unsolved exercises.
---
---Headings alone are too thin to navigate by — a generated MILbook section
---carries one `##` and twenty prose blocks — so an unheaded block is listed by
---its opening words, and the exercises are listed because they are what you
---came back for.
---@param buf integer?
---@return { row: integer, label: string, kind: "heading"|"prose"|"exercise" }[]
function M.entries(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local entries = {}
  local heading_rows = {}
  for _, h in ipairs(prose.headings(buf)) do
    heading_rows[h.row] = true
    entries[#entries + 1] = {
      row = h.row,
      kind = "heading",
      label = string.rep("  ", math.max(0, h.level - 1)) .. h.text,
    }
  end

  for _, block in ipairs(prose.blocks(buf)) do
    local lines = vim.api.nvim_buf_get_lines(buf, block.first, block.last + 1, false)
    local has_heading = false
    for i = 1, #lines do
      if heading_rows[block.first + i - 1] then
        has_heading = true
        break
      end
    end
    if not has_heading then
      for i, l in ipairs(lines) do
        if l:match("%S") and not l:match("^%s*/%-!%s*$") then
          local label = l:gsub("^%s+", "")
          if #label > 60 then
            label = label:sub(1, 57) .. "…"
          end
          entries[#entries + 1] = { row = block.first + i - 1, kind = "prose", label = "  ¶ " .. label }
          break
        end
      end
    end
  end

  local ok, exercises = pcall(require, "config.lean.exercises")
  if ok then
    for _, row in ipairs(exercises.unsolved(buf)) do
      local line = (vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""):gsub("^%s+", "")
      if #line > 58 then
        line = line:sub(1, 55) .. "…"
      end
      entries[#entries + 1] = { row = row, kind = "exercise", label = "  ◇ " .. line }
    end
  end

  table.sort(entries, function(a, b)
    return a.row < b.row
  end)
  return entries
end

---The contents as a location list, in the manner of `gO` in :help.
function M.outline()
  local buf = vim.api.nvim_get_current_buf()
  local entries = M.entries(buf)
  if #entries == 0 then
    vim.notify("lean notebook: nothing to outline in this buffer", vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, e in ipairs(entries) do
    items[#items + 1] = { bufnr = buf, lnum = e.row + 1, col = 1, text = e.label }
  end
  vim.fn.setloclist(0, {}, " ", { title = "Section contents", items = items })
  vim.cmd("lopen")
end

---Telescope picker over the same contents.
function M.pick_heading()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return M.outline()
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local buf = vim.api.nvim_get_current_buf()
  local entries = M.entries(buf)
  if #entries == 0 then
    vim.notify("lean notebook: nothing to outline in this buffer", vim.log.levels.INFO)
    return
  end

  pickers
    .new({}, {
      prompt_title = "Section contents",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          return { value = e, display = e.label, ordinal = e.label }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            vim.cmd("normal! m'")
            vim.api.nvim_win_set_cursor(0, { entry.value.row + 1, 0 })
            vim.cmd("normal! zz")
          end
        end)
        return true
      end,
    })
    :find()
end

-- ── cell views ────────────────────────────────────────────────────────────

---@alias lean.notebook.view "both"|"code"|"prose"

---@param buf integer?
---@return lean.notebook.view
function M.view(buf)
  return vim.b[buf or 0].lean_notebook_view or "both"
end

---Hide whichever half the current view excludes.
---@param buf integer
local function apply_view(buf)
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  local view = M.view(buf)
  if view == "both" then
    return
  end

  local in_prose = {}
  for _, b in ipairs(prose.blocks(buf)) do
    for row = b.first, b.last do
      in_prose[row] = true
    end
  end

  local total = vim.api.nvim_buf_line_count(buf)
  for row = 0, total - 1 do
    local hide = (view == "code") == (in_prose[row] == true)
    if hide then
      -- Keep the import prologue visible in every view: a Lean file whose
      -- imports have vanished reads as broken rather than as filtered.
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
      if not line:match("^import ") then
        vim.api.nvim_buf_set_extmark(buf, NS, row, 0, { conceal_lines = "" })
      end
    end
  end
end

---Cycle both → code only → prose only → both.
---@param buf integer?
function M.cycle_view(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  M.set_view(({ both = "code", code = "prose", prose = "both" })[M.view(buf)], buf)
end

---@param view lean.notebook.view
---@param buf integer?
function M.set_view(view, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not prose.is_on(buf) then
    vim.notify("lean notebook: prose rendering is off here (\\p)", vim.log.levels.WARN)
    return
  end
  vim.b[buf].lean_notebook_view = view
  apply_view(buf)
  vim.notify(({
    both = "notebook: prose and code",
    code = "notebook: code only",
    prose = "notebook: prose only",
  })[view], vim.log.levels.INFO)
end

---Re-apply after an edit; cheap enough to run on every change.
---@param buf integer?
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(buf) and M.view(buf) ~= "both" then
    apply_view(buf)
  end
end

return M
