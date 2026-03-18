---@type vim.lsp.Config
return {
  -- ruff server provides linting diagnostics only.
  -- Formatting is handled by ruff_format via conform.nvim.
  -- documentFormattingProvider is disabled in lsp.lua's LspAttach handler.
}
