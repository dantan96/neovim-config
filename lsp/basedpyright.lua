---@type vim.lsp.Config
return {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard",
        -- ruff owns unused-import/variable diagnostics (F401/F841);
        -- silence basedpyright's duplicates.
        diagnosticSeverityOverrides = {
          reportUnusedImport = "none",
          reportUnusedVariable = "none",
        },
        -- pythonVersion is intentionally omitted: basedpyright auto-detects
        -- from the active virtualenv or the system interpreter. Override
        -- per-project via pyproject.toml [tool.basedpyright] or pyrightconfig.json.
      },
    },
  },
}
