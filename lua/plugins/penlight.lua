-- lua/plugins/penlight.lua
return {
  -- Utility library, not used by this config itself. lazy = true: lazy.nvim
  -- loads it on demand when any of its modules (pl.*) is require()d, so
  -- ad-hoc scripts still work without paying the eager-load cost.
  { "lunarmodules/Penlight", lazy = true },
}
