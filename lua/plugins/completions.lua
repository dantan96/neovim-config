return {
  {
    'saghen/blink.cmp',
    dependencies = {
      'rafamadriz/friendly-snippets'
    },

    version = "*",

    opts = {
      keymap     = { preset = 'default' },

      appearance = {
        nerd_font_variant = 'mono'
      },

      signature  = { enabled = false }, -- noice.nvim owns signature help (lsp.signature)
      snippets   = { preset = "luasnip" },
    },
  },
}
