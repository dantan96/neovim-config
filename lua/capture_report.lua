-- capture_report.lua  – improved capture colour report for Neovim ≥ 0.11
local M = {}

local function hex(num)
  return num and string.format("#%06x", num) or ""
end

-- resolve highlight, following links
local function hl(group)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
  if not ok or not h then
    return {}
  end
  local fg = h.fg or h.foreground
  local bg = h.bg or h.background
  -- if still missing and a link exists, follow it once
  if not fg and h.link then
    local l_ok, l_h = pcall(vim.api.nvim_get_hl, 0, { name = h.link, link = false })
    if l_ok and l_h then
      fg = l_h.fg or l_h.foreground
      bg = l_h.bg or l_h.background
    end
  end
  return {
    fg = hex(fg),
    bg = hex(bg),
    attrs = table.concat({
      h.bold and "bold" or nil,
      h.italic and "italic" or nil,
      h.underline and "underline" or nil,
    }, " "),
    link = h.link or group,
  }
end

local function collect_semantic_groups(bufnr)
  local sg = {}
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    -- skip if server has no semantic-token capability
    if client.server_capabilities.semanticTokensProvider then
      local ns = vim.lsp.semantic_tokens.get_namespace(client.id) -- ↑ Nvim 0.10+
      if ns then
        -- extmarks carry {hl_group=...} in the details table
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
          local hl = mark[4] and mark[4].hl_group
          if hl then
            sg[hl] = true
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
    local group = "@" .. cap
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
    caps[hl_group:gsub("^@", "")] = true -- strip leading @
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
