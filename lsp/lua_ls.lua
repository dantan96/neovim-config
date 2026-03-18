---@type vim.lsp.Config
return {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim", "hs" } },
      workspace = {
        checkThirdParty = false,
        library = { vim.fn.stdpath("config") .. "/lua/types" },
      },
    },
  },
}
