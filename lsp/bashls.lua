---@type vim.lsp.Config
return {
  filetypes = { "sh", "bash", "zsh" },
  settings = {
    bashIde = {
      globPattern = "**/*@(.sh|.bash|.zsh|.env)",
      shellcheckPath = "shellcheck",
    },
  },
}
