-- lua/config/fsharp/highlights.lua
-- Custom F# highlight groups (treesitter captures + LSP semantic tokens).
-- Groups are global, so they are defined once per session and re-applied
-- on ColorScheme; the once-guard lives here instead of the ftplugin.

local M = {}

local GOLD = "#FFD700" -- CSS 'gold'
local g1 = { fg = GOLD, italic = true }

local function apply()
  vim.api.nvim_set_hl(
    0,
    "@variable.parameter.fsharp",
    { fg = "#f38ba8", bold = false, underline = false }
  )
  vim.api.nvim_set_hl(0, "@enum.member.fsharp", { fg = "#ff69b4" })
  vim.api.nvim_set_hl(0, "@lsp.type.enumMember.fsharp", { fg = "#ff69b4" })
  vim.api.nvim_set_hl(0, "@operator.fsharp", { fg = "#94e2d5" })
  vim.api.nvim_set_hl(0, "@lsp.type.operator.fsharp", { fg = "#94e2d5" })
  -- Cons operator "::" only (captured by queries/fsharp/highlights.scm in
  -- both expression and match-pattern positions): catppuccin pink.
  vim.api.nvim_set_hl(0, "@operator.cons.fsharp", { fg = "#f5c2e7" })
  vim.api.nvim_set_hl(
    0,
    "@lsp.type.type.fsharp",
    { fg = "#f9e2af", underline = false, bold = false }
  )
  vim.api.nvim_set_hl(
    0,
    "@type.fsharp",
    { fg = "#f9e2af", underline = false, bold = false }
  )
  vim.api.nvim_set_hl(0, "@lsp.type.typeParameter.fsharp", g1)

  vim.api.nvim_set_hl(
    0,
    "@keyword.modifier.fsharp",
    { fg = "#f2cdcd", bold = true }
  )
  vim.api.nvim_set_hl(
    0,
    "@module.builtin.fsharp",
    { fg = "#f9e2af", italic = true }
  )
  vim.api.nvim_set_hl(
    0,
    "@lsp.type.module.fsharp",
    { fg = "#f9e2af", italic = true, underline = true }
  )

  vim.api.nvim_set_hl(
    0,
    "@lsp.typemod.property.readonly",
    { fg = "#fab387", italic = true }
  )

  vim.api.nvim_set_hl(
    0,
    "@lsp.type.namespace.fsharp",
    { fg = "#f9e2af", italic = true }
  )
  vim.api.nvim_set_hl(
    0,
    "DiagnosticUnnecessary",
    { underline = nil, fg = nil, bg = nil, default = false }
  )
  vim.api.nvim_set_hl(
    0,
    "@variable.enum_member.fsharp",
    { fg = "#f5c2e7", underline = false }
  )
  vim.api.nvim_set_hl(
    0,
    "@punctuation.special",
    { fg = "#9399b2", underline = false }
  )

  -- ==========  BEEFING UP SEMANTIC COLOURING  ==========
  vim.api.nvim_set_hl(
    0,
    "@lsp.variable.enum_member.fsharp",
    { link = "@variable.enum_member.fsharp", default = false }
  )
end

-- Session-global guard (vim.g, not a module-local): `:source %` of
-- this file runs a FRESH chunk whose local guard is false, so a
-- module-local flag would let setup() re-run and reset module state
-- (the <space><space>x mapping makes that a real workflow).
function M.setup()
  -- Derived Ghostty profiles: these hexes are catppuccin-matched; let the
  -- profile colorscheme's capture defaults color F# instead (accepted
  -- trade: thematic consistency over hand-tuned colors). Queries stay
  -- active; only the color bindings stand down.
  if require("config.ghostty_profile").theme() then
    return
  end
  if vim.g._fsharp_hl_setup then
    return
  end
  vim.g._fsharp_hl_setup = true
  apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("fs_hl_reapply", { clear = true }),
    callback = apply,
  })
end

return M
