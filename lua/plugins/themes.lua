return {
  "catppuccin/nvim",
  name = "catppuccin",
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
        cmp = true, -- since you use blink.cmp
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
            CmpBorder = { fg = C.surface2 },
            Pmenu = { bg = C.none },
            TelescopeBorder = { link = "FloatBorder" },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
