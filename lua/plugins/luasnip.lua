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

      -- ── lean.nvim's own snippets, which never arrived ──────────────────
      -- lean.nvim ships snippets/lean.json (calc, example, namespace, ns,
      -- section) declared through its own package.json — and
      -- `require('luasnip').get_snippets('lean')` returned 0 in a live MIL
      -- buffer. Parity audit #41.
      --
      -- Load ordering, confirmed rather than assumed. The bare lazy_load()
      -- above resolves manifests with get_rtp_paths() AT LUASNIP CONFIG TIME
      -- (from_vscode.lua:473), and lean.nvim is not on the runtimepath then —
      -- it loads on `BufReadPre *.lean`. Measured live afterwards:
      -- nvim_get_runtime_file("snippets/lean.json", true) finds the file, so
      -- the path is right and only the timing was wrong.
      --
      -- A SECOND CALL, not a `paths` argument on the first one. `_load` uses
      -- `get_manifests(o.paths)`, whose rtp branch is the `else` of
      -- `if paths then` (from_vscode.lua:455-474) — passing `paths` REPLACES
      -- the runtimepath scan, so adding it to the existing call would have
      -- silently dropped friendly-snippets for every other language.
      --
      -- Resolved through lazy rather than hardcoding
      -- ~/.local/share/nvim/lazy/lean.nvim, and guarded, so a machine without
      -- lean.nvim (WorkBox) loads this file unchanged.
      local ok, lazy_config = pcall(require, "lazy.core.config")
      local spec = ok and lazy_config.plugins["lean.nvim"]
      if spec and spec.dir and vim.uv.fs_stat(spec.dir .. "/snippets/lean.json") then
        require("luasnip.loaders.from_vscode").lazy_load({ paths = { spec.dir } })
      end
    end,
  },
}
