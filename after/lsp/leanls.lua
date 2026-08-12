-- after/lsp/leanls.lua — extra client capabilities for Lean's language server.
--
-- This does NOT start a client. lean.nvim owns that: it ships its own
-- lsp/leanls.lua (cmd, root_dir, handlers) and calls vim.lsp.enable("leanls")
-- from lean.init(). vim.lsp.config resolution deep-merges EVERY lsp/<name>.lua
-- on the runtimepath (runtime/lua/vim/lsp.lua:351), and after/ comes last, so
-- this file adds to lean.nvim's config rather than competing with it — the
-- same reason bashls/remark_ls/raku_navigator live under after/ here.
--
-- Merged in, not replacing: the resolved capabilities still carry blink.cmp's
-- (via vim.lsp.config("*") in plugins/lsp.lua) and lean.nvim's own
-- `capabilities.lean = { silentDiagnosticSupport, rpcWireFormat }`.
--
-- ── the one conditional key ───────────────────────────────────────────────
-- `experimental.leanRichTokens` opts in to the rich semantic-token legend of
-- the patched toolchain in ~/ClaudeProjects/leanSetup/lean4-rich-tokens. The
-- extra token types are capability-gated THERE, so a client that has not asked
-- for them keeps receiving the stock legend, and a stock server ignores the
-- field entirely (LSP requires unknown capabilities to be ignored).
--
-- It is OMITTED rather than set to false when the user has forced standard
-- mode (`vim.g.lean_rich_tokens = false`): "not advertised" is the state the
-- server's gate is written against, and a literal `false` on the wire is a
-- different claim. Sending nothing is also what a client without this file
-- does, which is the behaviour being reproduced.
--
-- This file is `loadfile`d fresh on every vim.lsp.config resolution
-- (runtime/lua/vim/lsp.lua:351), and disabling a server drops the cached
-- resolution — so `:LeanRichTokens on|off` can change the answer within a
-- session by restarting leanls. See lua/config/lean/rich_tokens.lua.
if not require("config.lean.rich_tokens").advertise() then
  return {}
end

return {
  capabilities = {
    experimental = {
      leanRichTokens = true,
    },
  },
}
