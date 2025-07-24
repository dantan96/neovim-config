return {
  -- Core snippet engine required by blink.cmp
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",                  -- latest stable
    build   = "make install_jsregexp", -- optional, enables regex snippets
  },
}
