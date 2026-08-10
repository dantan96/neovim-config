---@type vim.lsp.Config
-- after/lsp/, not lsp/ — same rtp-precedence issue as remark_ls (35d1c1d)
-- and raku_navigator (25f9964): nvim-lspconfig ships its own lsp/bashls.lua
-- later in the runtimepath, so from a plain lsp/ file every key that
-- COLLIDES with theirs loses the tbl_deep_extend. globPattern is the one
-- that bit here — ours was silently replaced by lspconfig's
-- "*@(.sh|.inc|.bash|.command)", so .env was never indexed. (A plain lsp/
-- file is still fine for a config that collides on nothing, which is why
-- marksman and ruff stay put.)
--
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
