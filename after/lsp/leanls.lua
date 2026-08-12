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
-- `experimental.leanRichTokens` asks for the rich semantic-token legend of the
-- patched toolchain in ~/ClaudeProjects/leanSetup/lean4-rich-tokens. A stock
-- server ignores the field entirely, LSP requiring unknown capabilities to be
-- ignored, so it is inert on leanprover/lean4:v4.x releases.
--
-- IT IS NOT LOAD-BEARING TODAY, and an earlier version of this comment was
-- wrong to say the extra token types were capability-gated on the server side.
-- Measured against the patched build at d5f3797: `leanRichTokens` appears
-- nowhere in its source, and initializing `lake serve` with and without the
-- capability returns the identical rich legend. It is sent so that this client
-- is already correct if the gate lands, and nothing is inferred from having
-- sent it — lua/config/lean/rich_tokens.lua detects by reading the legend.
--
-- It is OMITTED rather than set to false when the user has forced standard
-- mode (`vim.g.lean_rich_tokens = false`): a gate would be written against
-- absence, and a literal `false` on the wire is a different claim. Sending
-- nothing is also exactly what a client without this file does, which is the
-- behaviour being reproduced.
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
