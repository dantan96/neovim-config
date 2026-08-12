---@type vim.lsp.Config
return {
  settings = {
    Lua = {
      -- No `diagnostics.globals`. Declaring a name global tells lua_ls to
      -- stop complaining without telling it what the name *is*, so every
      -- field access on it stays untyped — `vim.notify` was inferred from
      -- a test stub as `fun()` and produced 77 bogus redundant-parameter
      -- warnings. The real definitions are supplied instead by the
      -- checked-in `.luarc.json` at the repo root, which also reaches
      -- lua_ls instances launched outside Neovim (git worktrees, other
      -- editors, agents) where lazydev.nvim cannot run.
      --
      -- No custom library either: the old entry pointed at lua/types,
      -- which never existed (the stub lived at types/nvim.lua and was
      -- never loaded). Its loose signatures would only mask genuine
      -- diagnostics.
      workspace = {
        checkThirdParty = false,
      },
    },
  },
}
