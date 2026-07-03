---@type vim.lsp.Config
return {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard",
        -- pythonVersion is intentionally omitted: basedpyright auto-detects
        -- from the active virtualenv or the system interpreter. Override
        -- per-project via pyproject.toml [tool.basedpyright] or pyrightconfig.json.
      },
    },
  },
}
