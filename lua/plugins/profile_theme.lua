--nvim- Colorschemes for derived Ghostty profiles (GhosttyNu, GhosttyXonsh, ...).
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
    -- GhosttyNu's terminal identity IS Ghostty's stock ANSI palette over
    -- glass; nvim mirrors exactly that (mini.base16 over the same hexes)
    -- instead of importing a foreign synthwave scheme. Starship's neon
    -- decorates ONLY the statusline mode chips — the same relationship the
    -- prompt has to the terminal — never syntax.
    plugin = "echasnovski/mini.nvim",
    name = "mini.nvim",
    background = "dark",
    apply = function()
      require("mini.base16").setup({
        palette = {
          base00 = "#0d0e1a", -- glass ground (cleared to NONE anyway)
          base01 = "#1d1f21", -- ANSI 0
          base02 = "#33374a", -- selection: ground, lifted
          base03 = "#666666", -- ANSI 8 (comments)
          base04 = "#969896",
          base05 = "#c5c8c6", -- ANSI 7 (fg)
          base06 = "#eaeaea", -- ANSI 15
          base07 = "#ffffff",
          base08 = "#cc6666", -- ANSI 1 red
          base09 = "#d54e53", -- ANSI 9
          base0A = "#f0c674", -- ANSI 3 yellow
          base0B = "#b5bd68", -- ANSI 2 green
          base0C = "#8abeb7", -- ANSI 6 cyan
          base0D = "#81a2be", -- ANSI 4 blue
          base0E = "#b294bb", -- ANSI 5 magenta
          base0F = "#c397d8", -- ANSI 13
        },
      })
      local chips = {
        MiniStatuslineModeNormal = "#ff2e97",
        MiniStatuslineModeInsert = "#00e5ff",
        MiniStatuslineModeVisual = "#9d6bff",
        MiniStatuslineModeReplace = "#ff5566",
        MiniStatuslineModeCommand = "#b8ff5c",
        MiniStatuslineModeOther = "#586394",
      }
      for group, bg in pairs(chips) do
        vim.api.nvim_set_hl(0, group, { fg = "#0d0e1a", bg = bg, bold = true })
      end
      -- mini.base16 does not set colors_name; name it for debuggability.
      vim.g.colors_name = "nu-glass-ansi"
    end,
  },
}

local recipe = RECIPES[theme]
if recipe == nil then
  vim.notify(
    ("profile_theme: unknown GHOSTTY_NVIM_THEME %q; using default colors"):format(
      theme
    ),
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

local function transparency_autocmd()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup(
      "ghostty_profile_transparency",
      { clear = true }
    ),
    callback = make_transparent,
  })
end

if recipe.apply then
  -- Apply-based recipes (nu-glass) paint over plugins that already have
  -- their own lazy specs (mini.nvim). They MUST NOT contribute a plugin
  -- spec: a second spec for the same plugin would merge in lazy.nvim and
  -- our config would silently replace the plugin's real config (this
  -- happened: mini.statusline setup never ran). Instead: no spec at all,
  -- and a one-shot UIEnter apply after startup is fully assembled.
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      vim.o.background = recipe.background
      transparency_autocmd()
      if not pcall(recipe.apply) then
        vim.notify(
          "profile_theme: recipe apply failed; using default colors",
          vim.log.levels.WARN
        )
      end
      make_transparent()
      vim.o.pumblend = 10 -- popup legibility over glass
    end,
  })
  return {}
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
    transparency_autocmd()
    -- First launch in a profile installs the scheme from the network; if
    -- that ever fails, degrade to default colors rather than erroring on
    -- every startup.
    local ok = pcall(vim.cmd.colorscheme, recipe.colorscheme)
    if not ok then
      vim.notify(
        ("profile_theme: colorscheme %q unavailable (offline first launch?); using default colors"):format(
          recipe.colorscheme
        ),
        vim.log.levels.WARN
      )
      make_transparent()
    end
    vim.o.pumblend = 10 -- popup legibility over glass
  end,
}
