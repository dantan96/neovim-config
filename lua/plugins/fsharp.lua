-- lua/plugins/fsharp.lua
return {
  { -- Ionide-vim: F# ftplugin + helpers
    "ionide/Ionide-vim",
    ft = { "fsharp", "fs", "fsx", "fsi" }, -- lazy-load on first F# file
    init = function()
      -- Trim Ionide's indent dir *before* Vim starts loading runtime files
      local ionide = vim.fn.stdpath("data") .. "/lazy/Ionide-vim"
      vim.opt.rtp:remove(ionide .. "/indent")
    end,
    config = function()
      vim.g.Ionide_server_use_lspconfig = 1
      vim.g.Ionide_disable_mappings = 0
    end,
  },
}
