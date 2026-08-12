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
return {
  capabilities = {
    experimental = {
      -- Opt in to the rich semantic-token legend of the patched toolchain in
      -- ~/ClaudeProjects/leanSetup/lean4-rich-tokens. The extra token types
      -- are capability-gated there so a client that has not asked for them
      -- keeps receiving the stock legend. A stock server ignores the field
      -- entirely (LSP requires unknown capabilities to be ignored), so this
      -- is inert on leanprover/lean4:v4.x releases.
      leanRichTokens = true,
    },
  },
}
