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
  return {
    fg = hex(h.fg),
    bg = hex(h.bg),
    attrs = table.concat({
      h.bold and "bold" or nil,
      h.italic and "italic" or nil,
      h.underline and "underline" or nil,
    }, " "),
    link = h.link or group,
  }
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
  local lang = (function()
    local ok, p = pcall(vim.treesitter.get_parser, buf)
    return ok and p and p:lang() or nil
  end)()

  -- enumerate LSP clients using the modern API
  local lsp_lines = {}
  for _, client in pairs(vim.lsp.get_clients({ bufnr = buf })) do
    local tok = client.server_capabilities and client.server_capabilities.semanticTokensProvider and "✔" or "✘"
    table.insert(lsp_lines, ("• %s  (semantic-tokens %s)"):format(client.name, tok))
  end
  if #lsp_lines == 0 then
    lsp_lines[1] = "∅  (no LSP)"
  end

  local scheme = vim.g.colors_name or "NONE"

  -- build a set of capture names from the highlights query
  local caps = {}
  if lang then
    local q = vim.treesitter.query.get(lang, "highlights")
    if q then
      for _, name in pairs(q.captures or {}) do
        caps[name] = true
      end
    end
  end

  -- build the rows using the correct table (caps)
  local rows = build_rows(caps)

  -- print the report into a scratch buffer
  local out = vim.api.nvim_create_buf(false, true)
  local function add(line)
    vim.api.nvim_buf_set_lines(out, -1, -1, false, { line })
  end

  add("┏ Capture‑colour report ┓")
  add(("Tree‑sitter parser : %s"):format(lang or "none"))
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
