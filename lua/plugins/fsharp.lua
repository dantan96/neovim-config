-- lua/plugins/fsharp.lua
return {
  { -- Ionide-vim: F# ftplugin + helpers
    "ionide/Ionide-vim",
    ft = { "fsharp", "fs", "fsx", "fsi" }, -- lazy-load on first F# file
    config = function()
      -- 1. Tell Ionide to reuse your existing FsAutoComplete instance
      vim.g.Ionide_server_use_lspconfig = 1

      -- 2. Optionally enable its own key-mappings (disable if you prefer yours)
      vim.g.Ionide_disable_mappings = 0

      -- 3. The plugin’s ftplugin sets commentstring (// %s) automatically,
      --    so Comment.nvim now works without extra code.
    end,
  },
}
