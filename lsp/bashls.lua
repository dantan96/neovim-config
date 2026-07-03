---@type vim.lsp.Config
-- zsh is intentionally excluded: shellcheck (which bashls shells out to)
-- does not support zsh, so it would only produce false diagnostics.
return {
  filetypes = { "sh", "bash" },
  settings = {
    bashIde = {
      globPattern = "**/*@(.sh|.bash|.env)",
      shellcheckPath = "shellcheck",
    },
  },
}
