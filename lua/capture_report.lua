-- capture_report.lua  – improved capture colour report for Neovim ≥ 0.11
local M = {}

local function hex(num)
  return num and string.format("#%06x", num) or ""
end

-- resolve highlight, following links
local function hl(group)
  local fg, bg, attrs, root = nil, nil, nil, group -- root keeps the original name
  local seen = {} -- protect against circular links

  while group and not seen[group] do
    seen[group] = true
    local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
    if not ok or not h then
      break
    end

    -- grab attrs only from the first group we visit
    if not attrs then
      attrs = table.concat({
        h.bold and "bold" or nil,
        h.italic and "italic" or nil,
        h.underline and "underline" or nil,
      }, " ")
    end

    -- save colours if this hop defines them
    fg = fg or h.fg or h.foreground
    bg = bg or h.bg or h.background

    -- stop once we have a colour or there is nowhere else to hop
    if (fg or bg) or not h.link then
      break
    end
    group = h.link
  end

  return {
    fg = hex(fg),
    bg = hex(bg),
    attrs = attrs or "",
    link = group or root,
  }
end

-- helper: strip trailing ".<ft>" from @lsp.* groups
local function unsuffix(hl_group)
  local base, ft = hl_group:match("^(@lsp[%w%._]+)%.([%w_]+)$")
  if base and ft then
    return base -- "@lsp.type.property.lua" -> "@lsp.type.property"
  end
  return hl_group
end

-- Collect semantic‑token highlight groups for the given buffer.
-- Falls back to an empty set if semantic tokens are disabled or the
-- internal highlighter is unavailable.
local function collect_semantic_groups(bufnr)
  local sg = {}
  -- Access the private highlighter (added to M.__STHighlighter for testing).
  local ok, st = pcall(function()
    return vim.lsp.semantic_tokens.__STHighlighter
  end)
  if ok and st and st.active then
    local highlighter = st.active[bufnr]
    if highlighter and highlighter.client_state then
      for client_id, state in pairs(highlighter.client_state) do
        local ns = state.namespace -- extmark namespace for this client
        if ns then
          -- Each extmark’s details contains the hl_group used by the semantic token
          for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
            local details = mark[4]
            local hl_group = details and details.hl_group
            if hl_group then
              sg[hl_group] = true
            end
          end
        end
      end
    end
  end
  return sg
end

-- build rows of capture → colour
local function build_rows(captures)
  local rows = { { "capture", "fg", "bg", "attrs", "link" } }
  captures = captures or {}
  for cap in pairs(captures) do
    local group = cap:match("^@") and cap or ("@" .. cap)
    local hinfo = hl(group)
    rows[#rows + 1] = { cap, hinfo.fg, hinfo.bg, hinfo.attrs, hinfo.link }
  end
  return rows
end

function M.run()
  local buf = vim.api.nvim_get_current_buf()

  -- active TS language -------------------------------------------------------
  local lang = (function()
    local ok, p = pcall(vim.treesitter.get_parser, buf)
    return ok and p and p:lang() or nil
  end)()

  -- active LSP clients -------------------------------------------------------
  local lsp_lines = {}
  for _, cli in pairs(vim.lsp.get_clients({ bufnr = buf })) do
    local tok = cli.server_capabilities and cli.server_capabilities.semanticTokensProvider and "✔" or "✘"
    lsp_lines[#lsp_lines + 1] = ("• %s  (semantic-tokens %s)"):format(cli.name, tok)
  end
  if #lsp_lines == 0 then
    lsp_lines[1] = "∅  (no LSP)"
  end

  local scheme = vim.g.colors_name or "NONE"

  ---------------------------------------------------------------------------
  -- 1. Capture names from Tree-sitter highlights query
  ---------------------------------------------------------------------------
  local caps = {}
  if lang then
    local q = vim.treesitter.query.get(lang, "highlights")
    if q then
      for _, name in pairs(q.captures or {}) do
        caps[name] = true
      end
    end
  end

  ---------------------------------------------------------------------------
  -- 2. Merge in highlight groups used by LSP semantic tokens
  ---------------------------------------------------------------------------
  for hl_group in pairs(collect_semantic_groups(buf)) do
    -- always keep the exact name we got from extmarks/completion
    caps[hl_group] = true -- e.g. "@lsp.type.property.lua"

    -- add the unsuffixed form *in addition*, so colours resolve even if
    -- only the generic group is defined in the theme
    local generic = hl_group:gsub("%.[%w_]+$", "") -- drop ".lua", ".py", …
    if generic ~= hl_group then
      caps[generic] = true
    elseif not hl_group:match("^@") then -- Tree-sitter capture
      caps[hl_group:gsub("^@", "")] = true -- strip single "@"
    end
  end

  -- fallback: any highlight group already defined that starts with @lsp.
  for _, name in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
    caps[name] = true
    local generic = name:gsub("%.[%w_]+$", "")
    if generic ~= name then
      caps[generic] = true
    end
  end

  ---------------------------------------------------------------------------
  -- 3. Build & sort rows
  ---------------------------------------------------------------------------
  local rows = build_rows(caps)
  local header = table.remove(rows, 1) -- keep the header out of the sort
  table.sort(rows, function(a, b)
    return a[1] < b[1]
  end)
  table.insert(rows, 1, header)

  ---------------------------------------------------------------------------
  -- 4. Display in scratch buffer
  ---------------------------------------------------------------------------
  local out = vim.api.nvim_create_buf(false, true)
  local add = function(s)
    vim.api.nvim_buf_set_lines(out, -1, -1, false, { s })
  end

  add("┏ Capture-colour report ┓")
  add(("Tree-sitter parser : %s"):format(lang or "none"))
  add(("Colourscheme       : %s"):format(scheme))
  add("LSP clients        :")
  for _, l in ipairs(lsp_lines) do
    add("  " .. l)
  end
  add("")
  add(string.format("%-30s %-9s %-9s %-12s %s", unpack(rows[1])))
  for i = 2, #rows do
    add(string.format("%-30s %-9s %-9s %-12s %s", unpack(rows[i])))
  end

  vim.bo[out].modifiable = false
  vim.bo[out].filetype = "capture_report"
  vim.api.nvim_set_current_buf(out)
end

-- register a command and optional keymap for convenience
function M.setup(opts)
  opts = opts or {}
  local cmd = opts.command or "CaptureReport"
  local key = opts.keymap
  vim.api.nvim_create_user_command(cmd, M.run, { desc = "Show capture colours" })
  if key then
    vim.keymap.set("n", key, M.run, {
      desc = "Capture‑colour report",
      noremap = true,
      silent = true,
    })
  end
end

return M
