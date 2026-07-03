return {
  -- Core snippet engine required by blink.cmp
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",                  -- latest stable
    build   = "make install_jsregexp", -- optional, enables regex snippets
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      -- Load the community (friendly-snippets) vscode-style snippets so
      -- blink.cmp's `snippets = { preset = "luasnip" }` has something to serve.
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
}
