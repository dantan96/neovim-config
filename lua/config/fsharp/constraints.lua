-- lua/config/fsharp/constraints.lua
-- Overlay: light up constraint-name words (comparison, equality, ...)
-- inside (constraint) treesitter nodes, via extmarks in a dedicated
-- namespace. setup() is once-guarded; refresh()/set_color() are exposed
-- for reuse (and for tests).

local M = {}

local ts = vim.treesitter

local ns_constraints = vim.api.nvim_create_namespace("fs_constraint_names")

-- Words to light up inside constraint nodes (word-boundary safe).
local CONSTRAINT_PATTERNS = {
  "%f[%w_]comparison%f[^%w_]",
  "%f[%w_]equality%f[^%w_]",
  "%f[%w_]struct%f[^%w_]",
  "%f[%w_]unmanaged%f[^%w_]",
  "%f[%w_]enum%f[^%w_]",
  "%f[%w_]delegate%f[^%w_]",
  -- two-word form:
  "%f[%w_]not%f[^%w_]%s+%f[%w_]struct%f[^%w_]",
}

-- Treesitter query to grab constraint nodes. Parsed lazily and cached on
-- success: if the fsharp parser is not yet registered (nvim-treesitter
-- not loaded when the first F# buffer opens), refresh degrades to a
-- no-op and simply retries the parse on the next call, instead of
-- permanently giving up (the old per-source pcall re-tried per buffer).
local constraint_query = nil
local function get_query()
  if constraint_query then
    return constraint_query
  end
  local ok, q = pcall(ts.query.parse, "fsharp", "(constraint) @c")
  if ok then
    constraint_query = q
  end
  return constraint_query
end

-- === extmark highlighter (replacement for deprecated add_highlight) ===
local function hl_add(buf, lnum, start_col, end_col)
  vim.api.nvim_buf_set_extmark(buf, ns_constraints, lnum, start_col, {
    end_row = lnum,
    end_col = end_col,
    hl_group = "FsharpConstraint",
    priority = 130,
  })
end

local function find_all_ranges(line, col_start, col_end)
  local sub = line:sub(col_start + 1, col_end)
  local out = {}
  for _, patt in ipairs(CONSTRAINT_PATTERNS) do
    local idx = 1
    while true do
      local a, b = sub:find(patt, idx)
      if not a then
        break
      end
      table.insert(out, { col_start + a - 1, col_start + b }) -- [start, end)
      idx = b + 1
    end
  end
  return out
end

-- Use iter_captures() so we always get a TSNode, never a table/nil
function M.refresh(buf)
  local query = get_query()
  if not query then
    return
  end
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "fsharp" then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns_constraints, 0, -1)

  local parser_ok, parser = pcall(ts.get_parser, buf, "fsharp")
  if not parser_ok or not parser then
    return
  end

  local trees = parser:parse()
  if not trees or #trees == 0 then
    return
  end

  for _, tree in ipairs(trees) do
    local root = tree:root()

    -- NB: iter_captures returns (capture_id, node, metadata)
    for _, node, _ in query:iter_captures(root, buf, 0, -1) do
      -- At this point `node` is a TSNode (has :range()).
      local srow, scol, erow, ecol = node:range()

      for lnum = srow, erow do
        local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1]
          or ""
        local from = (lnum == srow) and scol or 0
        local to = (lnum == erow) and ecol or #line

        for _, r in ipairs(find_all_ranges(line, from, to)) do
          hl_add(buf, lnum, r[1], r[2])
        end
      end
    end
  end
end

M.DEFAULT_COLOR = "#ff00ff" -- bright magenta

-- Remembered so the ColorScheme handler can re-apply it: :colorscheme
-- clears user-defined groups, and with setup() once-guarded there is no
-- per-buffer re-source to heal FsharpConstraint afterwards.
local current_color = M.DEFAULT_COLOR

--- Set the FsharpConstraint color and repaint.
function M.set_color(hex)
  current_color = hex
  vim.api.nvim_set_hl(0, "FsharpConstraint", {
    fg = hex,
    italic = true,
    bold = false, -- keep crisp; turn on if you want extra punch
    nocombine = true,
  })
  pcall(M.refresh, 0)
end

local done = false

function M.setup()
  if done then
    return
  end
  done = true

  -- Refresh on typical edit/parse events (cheap: only scans constraint
  -- nodes; deferred to avoid fast-event yields).
  vim.api.nvim_create_autocmd(
    { "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" },
    {
      group = vim.api.nvim_create_augroup(
        "fs_constraint_names_refresh",
        { clear = true }
      ),
      pattern = { "*.fs", "*.fsx", "*.fsi" },
      callback = function(args)
        -- Defer out of Treesitter's fast C-callback to prevent
        -- "yield across C-call boundary"
        vim.schedule(function()
          pcall(M.refresh, args.buf)
        end)
      end,
    }
  )

  -- Re-apply the group and repaint after any colorscheme change:
  -- :colorscheme clears FsharpConstraint, so a refresh alone would paint
  -- extmarks with an empty group (invisible). Separate autocmds because
  -- ColorScheme matches the colorscheme NAME while BufWritePost matches
  -- file PATHS.
  local colors_group =
    vim.api.nvim_create_augroup("fs_constraint_names_colors", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = colors_group,
    callback = function()
      M.set_color(current_color)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = colors_group,
    pattern = { "*.fs", "*.fsx", "*.fsi" },
    callback = function(args)
      M.refresh(args.buf)
    end,
  })

  M.set_color(M.DEFAULT_COLOR)
end

return M
