-- Colorschemes for derived Ghostty profiles (GhosttyNu, GhosttyXonsh, ...).
-- Inert in plain Ghostty: when config.ghostty_profile detects no theme this
-- module contributes nothing at all (catppuccin owns that world; see the
-- `enabled` gate in themes.lua and the baseline in tests/test_profile_theme.lua).
local theme = require("config.ghostty_profile").theme()
if theme == nil then
  return {}
end

-- One recipe per GHOSTTY_NVIM_THEME value (injected by the Ghostty variant
-- configs under ~/.config/ghostty/variants/). Custom syntax-color hooks
-- stand down in derived profiles; the recipe scheme's capture defaults do
-- the coloring (accepted trade: consistency over customization).
local RECIPES = {
  vellum = {
    plugin = "kepano/flexoki-neovim",
    name = "flexoki",
    colorscheme = "flexoki-light",
    background = "light",
  },
  ["flexoki-dark"] = {
    plugin = "kepano/flexoki-neovim",
    name = "flexoki",
    colorscheme = "flexoki-dark",
    background = "dark",
  },
  ["nu-glass"] = {
    plugin = "maxmx03/fluoromachine.nvim",
    name = "fluoromachine",
    colorscheme = "fluoromachine",
    background = "dark",
    setup = function()
      require("fluoromachine").setup({
        glow = false,
        theme = "fluoromachine",
        transparent = true,
      })
    end,
  },
}

local recipe = RECIPES[theme]
if recipe == nil then
  vim.notify(
    ("profile_theme: unknown GHOSTTY_NVIM_THEME %q; using default colors"):format(theme),
    vim.log.levels.WARN
  )
  return {}
end

-- Ghostty's glass/blur shows only through cells nvim leaves unpainted, so
-- transparency = clearing backgrounds on this canonical set. Merge-clear
-- (preserve fg/attrs), reapplied on ColorScheme so it survives reloads.
local CLEAR_BG = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "FloatBorder",
  "SignColumn",
  "EndOfBuffer",
  "StatusLine",
  "StatusLineNC",
  "WinSeparator",
  "MiniStatuslineFilename",
  "MiniStatuslineFileinfo",
  "MiniStatuslineInactive",
}

local function make_transparent()
  for _, group in ipairs(CLEAR_BG) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    if hl.bg ~= nil then
      hl.bg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
  end
end

return {
  recipe.plugin,
  name = recipe.name,
  lazy = false,
  priority = 1000, -- like themes.lua: before other start plugins
  config = function()
    -- Pre-set background so nvim's async OSC 11 autodetection writes the
    -- same value it discovers (no-op, no reload flash).
    vim.o.background = recipe.background
    if recipe.setup then
      pcall(recipe.setup)
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ghostty_profile_transparency", { clear = true }),
      callback = make_transparent,
    })
    -- First launch in a profile installs the scheme from the network; if
    -- that ever fails, degrade to default colors rather than erroring on
    -- every startup.
    local ok = pcall(vim.cmd.colorscheme, recipe.colorscheme)
    if not ok then
      vim.notify(
        ("profile_theme: colorscheme %q unavailable (offline first launch?); using default colors"):format(recipe.colorscheme),
        vim.log.levels.WARN
      )
      make_transparent()
    end
    vim.o.pumblend = 10 -- popup legibility over glass
  end,
}
