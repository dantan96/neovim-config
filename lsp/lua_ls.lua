---@type vim.lsp.Config
return {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim", "hs" } },
      workspace = {
        checkThirdParty = false,
        -- No custom library: the old entry pointed at lua/types, which
        -- never existed (the stub lived at types/nvim.lua and was never
        -- loaded). lazydev.nvim supplies the real runtime types; the
        -- hand-rolled stub was deleted rather than wired in, since its
        -- loose signatures (vim.opt as table<string,any> etc.) would
        -- only mask genuine diagnostics.
      },
    },
  },
}
