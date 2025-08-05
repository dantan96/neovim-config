-- ~/.config/nvim/lua/capture_report.lua  (Neovim ≥0.11)
local M = {}

-- helper ------------------------------------------------------------------
local function hex(num)
  return num and string.format("#%06x", num) or ""
end
local function hl(group)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
  if not ok then
    return {}
  end
  h.fg, h.bg = hex(h.foreground), hex(h.background)
  h.link = h.link or group -- resolved link target (self if none)
  return h
end

local function build_rows(captures)
  local rows = { { "capture", "fg", "bg", "attrs", "link" } }
  for cap in pairs(captures) do
    local grp = "@" .. cap
    local h = hl(grp) -- ← resolves fg/bg
    rows[#rows + 1] = { cap, h.fg, h.bg, h.attrs, h.link }
  end
  return rows
end

-- main --------------------------------------------------------------------
function M.run()
  local buf = vim.api.nvim_get_current_buf()

  -- (a) active Tree-sitter language
  local lang = (function()
    local ok, p = pcall(vim.treesitter.get_parser, buf)
    return ok and p and p:lang()
  end)()

  -- (b) LSP + semantic-token support (modern helper)
  local lsp_lines = {}
  for _, cli in pairs(vim.lsp.get_clients({ bufnr = buf })) do
    local tok = cli.server_capabilities.semanticTokensProvider and "✔" or "✘"
    table.insert(lsp_lines, ("• %s  (semantic-tokens %s)"):format(cli.name, tok))
  end
  if #lsp_lines == 0 then
    lsp_lines[1] = "∅  (no LSP)"
  end

  -- (c) current colourscheme
  local scheme = vim.g.colors_name or "NONE"

  -- (d) capture names that actually appear in buffer
  local caps = {}
  if lang then
    local q = vim.treesitter.query.get(lang, "highlights")
    if q then
      for _, name in pairs(q.captures) do
        caps[name] = true
      end
    end
  end

  -- (e) resolve colour for every capture
  local rows = build_rows(captures)
  for cap in pairs(caps) do
    local h = hl(cap)
    rows[#rows + 1] = { cap, h.fg, h.bg, h.link }
  end

  -- (f) pretty-print
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
  add(string.format("%-30s %-9s %-9s %s", unpack(rows[1])))
  for i = 2, #rows do
    add(string.format("%-30s %-9s %-9s %s", unpack(rows[i])))
  end

  vim.bo[out].modifiable = false
  vim.bo[out].filetype = "capture_report"
  vim.api.nvim_set_current_buf(out)
end

function M.setup(opts)
  opts = opts or {}
  local cmd = opts.command or "CaptureReport"
  local key = opts.keymap

  vim.api.nvim_create_user_command(cmd, M.run, { desc = "Show capture colours" })
  if key then
    vim.keymap.set("n", key, M.run, { desc = "Capture-colour report", noremap = true, silent = true })
  end
end

return M
