---@type vim.lsp.Config
return {
  -- ruff server provides linting diagnostics only.
  -- Formatting is handled by ruff_format via conform.nvim.
  -- documentFormattingProvider is disabled in lsp.lua's LspAttach handler.
  -- Settings (lineLength, lint.select) come from pyproject.toml.
  -- No init_options overrides needed.
  on_attach = function(client, _)
    -- Disable hover in favor of Pyright/Basedpyright
    client.server_capabilities.hoverProvider = false
  end,
}
