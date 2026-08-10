return {
  "catppuccin/nvim",
  name = "catppuccin",
  -- Derived Ghostty profiles (see lua/config/ghostty_profile.lua) bring
  -- their own colorscheme via lua/plugins/profile_theme.lua; catppuccin
  -- stands down there and ONLY there. tests/test_profile_theme.lua pins
  -- the plain-Ghostty baseline against this condition ever inverting.
  enabled = require("config.ghostty_profile").theme() == nil,
  lazy = false,
  priority = 1000, -- load the colorscheme before other start plugins
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      term_colors = true,
      transparent_background = false,
      no_italic = false,
      no_bold = false,
      -- New: semantic highlighting
      integrations = {
        treesitter = true, -- syntax captures
        semantic_tokens = true, -- LSP semantic-highlight captures
        native_lsp = {
          enabled = true,
          underlines = { errors = { "undercurl" } },
        },
        blink_cmp = true, -- blink.cmp integration (`cmp` is the nvim-cmp key)
        gitsigns = true,
      },
      color_overrides = {
        mocha = {
          -- base = "#000000",
          -- mantle = "#000000",
          -- crust = "#000000",
          base = "#151520",
          mantle = "#101019",
          crust = "#0b0b12",
        },
      },
      highlight_overrides = {
        mocha = function(C)
          return {
            TabLineSel = { bg = C.pink },
            -- Gutter numbers on soft-wrap continuation rows (see the vnum
            -- segment in lua/plugins/statuscol.lua): one step dimmer than
            -- LineNr (surface1) so true lines stand out from wrap segments.
            LineNrWrap = { fg = C.surface0 },
            CmpBorder = { fg = C.surface2 },
            Pmenu = { bg = C.none },
            TelescopeBorder = { link = "FloatBorder" },
            -- Lean's language server emits two semantic-token types that
            -- catppuccin leaves undefined, so they rendered unstyled: plain
            -- `variable`, and Lean's own `leanSorryLike` (sorry/admit and
            -- friends). Defined here rather than in the ftplugin so they
            -- survive a colorscheme reload, as with LineNrWrap above.
            ["@lsp.type.variable.lean"] = { link = "Identifier" },
            ["@lsp.type.leanSorryLike.lean"] = { fg = C.base, bg = C.yellow, bold = true },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
