---@type vim.lsp.Config
-- nvim-lspconfig ships raku_navigator with an empty `cmd` (it won't guess a
-- path), so the only thing strictly required here is pointing at server.js.
--
-- The server is bscan/RakuNavigator's language server, which VS Code's
-- raku-navigator extension also bundles. It is copied to a stable path rather
-- than referenced inside ~/.vscode/extensions/bscan.raku-navigator-<ver>/ so a
-- version bump — or uninstalling the extension — doesn't silently break LSP
-- here. Refresh it with:
--   cp -R ~/.vscode/extensions/bscan.raku-navigator-*/server/ \
--         ~/.local/share/raku-navigator/
--
-- The directory must be copied whole: server.js resolves raku.tmLanguage.json
-- and the src/raku/*.raku helper scripts by relative path.
return {
  cmd = {
    "node",
    vim.fn.expand("~/.local/share/raku-navigator/out/server.js"),
    "--stdio",
  },
  filetypes = { "raku" },
  -- META6.json marks a Raku distribution root, which is what workspace symbol
  -- indexing should span; .git is the fallback for loose scripts.
  root_markers = { "META6.json", ".git" },
}
