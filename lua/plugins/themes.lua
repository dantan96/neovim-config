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
            -- The propositional half of Lean, split out of lean.nvim's syntax
            -- file by after/syntax/lean.vim. One hue family, green/teal, so
            -- "this is a proposition" reads at a glance: the keyword, the name
            -- it binds, the sort Prop lives in, and the connectives. Data
            -- declarations keep the stock mauve `def` / blue name.
            --
            -- Green doubles as String in catppuccin, which is a real but tiny
            -- collision: string literals barely occur in mathlib-style Lean.
            -- Cleared, not recoloured. leanls tags `theorem`, `def`, `by`,
            -- `#check` and friends all as semantic-token type `keyword` (164
            -- of them on C02_Basics/S02), and a semantic extmark outranks
            -- syntax, so every keyword arrived one flat colour and the split
            -- below was invisible. An empty definition makes the extmark
            -- contribute no attributes and the syntax group underneath show
            -- through — the documented way to opt out (:h lsp-semantic-
            -- highlight). Verified in a real TUI: with the override, `theorem`
            -- renders #a6e3a1 and `#check` stays #cba6f7; without it, both are
            -- #cba6f7. Nothing is lost, because lean.nvim's syntax file
            -- already covers the same keywords.
            ["@lsp.type.keyword.lean"] = {},
            leanPropDeclaration = { fg = C.green, bold = true },
            leanPropName = { fg = C.green },
            leanProp = { fg = C.green, bold = true },
            leanLogicOp = { fg = C.teal },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
