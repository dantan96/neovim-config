-- after/ftplugin/lean.lua — buffer-local settings for Lean 4 files.
--
-- Everything here MUST be buffer- or window-local (vim.bo / vim.wo /
-- opt_local): tests/test_invariants.lua asserts that visiting a buffer of any
-- configured filetype leaves every global option value untouched.
--
-- It must also be re-source-safe. The same test re-sources each ftplugin twice
-- via `:edit!` and requires the config's autocmd population to be unchanged,
-- so this file defines no autocmds and its one list-option edit is guarded.

-- mathlib's style guide: two spaces, never tabs, 100-column lines.
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.tabstop = 2
vim.bo.textwidth = 100

-- ...but textwidth alone is a trap here. The global formatoptions is "tcqj",
-- and `t` hard-wraps as you type, which splits long Lean terms mid-expression.
-- Drop `t` so textwidth only governs explicit `gq`, and show the limit with a
-- colorcolumn instead. Scoped as vim.wo[0][0] (window option, buffer-local
-- semantics) so it does not leak into the next buffer shown in this window.
vim.opt_local.formatoptions:remove("t")
vim.wo[0][0].colorcolumn = "100"

-- Primed names (`h'`, `ih₂'`) are pervasive in Lean and mathlib, so `w`, `*`
-- and completion should treat the apostrophe as part of the identifier.
-- Guarded because ftplugins re-run on every :edit and `:append` is not
-- idempotent.
if not vim.tbl_contains(vim.opt_local.iskeyword:get(), "'") then
  vim.opt_local.iskeyword:append("'")
end

-- lean.nvim installs its mappings under <LocalLeader> ("\"), which is not a
-- global mini.clue trigger. Register it for this buffer only, so `\` shows the
-- Lean hint window in Lean files and stays inert everywhere else. mini.clue
-- re-reads vim.b.miniclue_config on BufWinEnter and LspAttach (both of which
-- fire after this ftplugin), so no explicit ensure_buf_triggers() is needed.
vim.b.miniclue_config = {
  triggers = { { mode = "n", keys = "<LocalLeader>" } },
  clues = {
    { mode = "n", keys = "<LocalLeader>i", desc = "Toggle infoview" },
    { mode = "n", keys = "<LocalLeader>p", desc = "Pause infoview pin" },
    { mode = "n", keys = "<LocalLeader>r", desc = "Restart Lean server" },
    { mode = "n", keys = "<LocalLeader>s", desc = "Accept 'Try this'" },
    { mode = "n", keys = "<LocalLeader>v", desc = "Infoview view options" },
    { mode = "n", keys = "<LocalLeader>x", desc = "Place infoview pin" },
    { mode = "n", keys = "<LocalLeader>c", desc = "Clear all pins" },
    { mode = "n", keys = "<LocalLeader>w", desc = "Enable widgets" },
    { mode = "n", keys = "<LocalLeader>W", desc = "Disable widgets" },
    { mode = "n", keys = "<LocalLeader>d", desc = "+diff pins" },
    { mode = "n", keys = "<LocalLeader><Tab>", desc = "Jump into infoview" },
    { mode = "n", keys = "<LocalLeader>\\", desc = "Abbreviation for symbol" },
  },
}
