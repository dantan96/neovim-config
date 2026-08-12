-- after/ftplugin/lean.lua — buffer-local settings for Lean 4 files.
--
-- Everything here MUST be buffer- or window-local (vim.bo / vim.wo /
-- opt_local): tests/test_invariants.lua asserts that visiting a buffer of any
-- configured filetype leaves every global option value untouched. The same
-- rule applies to state that is not an option and so is invisible to that
-- snapshot — vim.lsp.inlay_hint.enable() below takes a { bufnr } filter for
-- exactly this reason.
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
-- Drop `t` so textwidth only governs explicit `gq` on comments.
--
-- No colorcolumn: the 100-column rule is mathlib's contribution guideline, not
-- something to be nagged about while working through exercises, and a ruler
-- competes with the infoview split for horizontal room.
vim.opt_local.formatoptions:remove("t")

-- ── Folding, from the language server ─────────────────────────────────────
-- Lean's grammar is user-extensible — `notation`, `macro_rules` and `syntax`
-- can invent statement forms at will — so no regex and no tree-sitter grammar
-- can reliably say where a declaration ends. The server can: it implements
-- textDocument/foldingRange (Lean/Server/FileWorker/RequestHandling.lean:537),
-- and Neovim ≥0.11 ships vim.lsp.foldexpr to consume it.
--
-- vim.wo[0][0], NOT vim.opt_local: 'foldmethod'/'foldexpr'/'foldlevel' are
-- window options, and a plain :setlocal sticks them to the WINDOW — :edit a
-- Lua file into this window afterwards and it would still be folding through
-- vim.lsp.foldexpr(). The [0][0] form scopes the value to this buffer in this
-- window, so it reverts on switching buffers. Same bug class as the global
-- leak tests/test_invariants.lua guards, one scope out.
--
-- 'foldlevel' rather than 'foldlevelstart', which is global-only and so out of
-- bounds for an ftplugin. 99 means every fold starts open: folds are here to
-- be used deliberately (zc/zo/zM), not to hide the file on arrival.
--
-- Degrades to "no folds" rather than to breakage when no server is attached:
-- vim.lsp.foldexpr() returns "0" for every line until a client supporting
-- foldingRange appears (runtime/lua/vim/lsp/_folding_range.lua:349-355).
vim.wo[0][0].foldmethod = "expr"
vim.wo[0][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
vim.wo[0][0].foldlevel = 99

-- ── Inlay hints ───────────────────────────────────────────────────────────
-- On by default, and load-bearing rather than decorative here: in Lean 4.30
-- the only inlay hints the server emits are auto-bound implicits
-- (Lean/Elab/Term/TermElabM.lean:1989 `addAutoBoundImplicitsInlayHint`, whose
-- label is the ` {α}` Lean silently inserted). Upstream leaves global
-- constants uncoloured precisely so an accidental auto-implicit — `nat` for
-- `Nat` — shows up coloured against uncoloured neighbours; the patched server
-- this config styles for colours globals, which spends that contrast, so the
-- explicit signal replaces it.
--
-- The bufnr filter is not optional: vim.lsp.inlay_hint.enable(true) with no
-- filter sets a GLOBAL flag and enables hints in every loaded buffer.
--
-- Applied ONCE PER BUFFER, not on every run of this file. An ftplugin re-runs
-- on every :edit of the same buffer — including :edit! and the automatic
-- reload after an external write (a `lake build` touching the file) — so an
-- unconditional enable() here silently reverted any \h toggle the user had
-- made: the toggle appeared to work and then quietly stopped holding. A
-- buffer-local flag is the right memory for this, because :edit reloads a
-- buffer's CONTENTS without destroying the buffer, so `b:` variables survive
-- exactly the event that was undoing the toggle.
local bufnr = vim.api.nvim_get_current_buf()
if not vim.b[bufnr].lean_inlay_hints_defaulted then
  vim.b[bufnr].lean_inlay_hints_defaulted = true
  vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
end

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
    -- Defined below, not by lean.nvim.
    { mode = "n", keys = "<LocalLeader>?", desc = "Lean cheatsheet" },
    { mode = "n", keys = "<LocalLeader>n", desc = "Rename" },
    { mode = "n", keys = "<LocalLeader>a", desc = "Code action" },
    { mode = "n", keys = "<LocalLeader>f", desc = "References" },
    { mode = "n", keys = "<LocalLeader>b", desc = "Open book page" },
    { mode = "n", keys = "<LocalLeader>h", desc = "Toggle inlay hints" },
    { mode = "n", keys = "<LocalLeader>D", desc = "Declaration (parser/elaborator)" },
    { mode = "n", keys = "<LocalLeader>m", desc = "+module hierarchy" },
    { mode = "n", keys = "<LocalLeader>mi", desc = "Imports of this module" },
    { mode = "n", keys = "<LocalLeader>mI", desc = "Modules importing this one" },
    { mode = "n", keys = "<LocalLeader>l", desc = "+lemma search" },
    { mode = "n", keys = "<LocalLeader>ll", desc = "Loogle (by type pattern)" },
    { mode = "n", keys = "<LocalLeader>lw", desc = "Workspace symbols (by name)" },
    { mode = "n", keys = "<LocalLeader>la", desc = "Unicode abbreviations" },
    { mode = "n", keys = "<LocalLeader>y", desc = "Yank module name" },
  },
}

-- LSP actions.
--
-- These were WORKAROUNDS: mini.operators owned the `gr` prefix and its setup
-- deletes Neovim's built-in grn/gra/grr/gri/grt outright, so rename, code
-- action and references were unreachable here. That is fixed at the source now
-- — plugins/mini.lua moves the replace operator to `gR`, and the built-ins come
-- back on their own — so `grn` / `gra` / `grr` / `gri` / `grt` work in a Lean
-- buffer exactly as they do everywhere else.
--
-- KEPT ANYWAY, as aliases. They cost three lines, they are in the cheatsheet
-- and in the `\` clue window, they are what is already in the fingers, and
-- `\`-prefixed maps are where every other Lean action lives — so `\n` sits
-- next to `\i`/`\r`/`\v` rather than in a separate vocabulary. Nothing depends
-- on them being the ONLY route, which was the actual problem.
local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
end
map("<LocalLeader>n", vim.lsp.buf.rename, "Rename")
map("<LocalLeader>a", vim.lsp.buf.code_action, "Code action")
map("<LocalLeader>f", vim.lsp.buf.references, "References")

-- Go to Declaration, which in Lean is NOT a synonym for Go to Definition: the
-- server additionally returns the parser and the elaborator of the symbol
-- (vscode-lean4 manual.md:552), which is the direct answer to "which notation
-- produced this?". Advertised as declarationProvider by the server, and Neovim
-- ships no default map for it — unlike gri/grt, which came back for free when
-- plugins/mini.lua stopped deleting them.
map("<LocalLeader>D", vim.lsp.buf.declaration, "Declaration (parser/elaborator)")

-- ── \m · module hierarchy ─────────────────────────────────────────────────
-- :LeanModuleImports / :LeanModuleImportedBy have existed since lean.nvim
-- picked up Lean 4.22's module-hierarchy requests (init.lua:199-204) and were
-- reachable only by typing the full command. MIL chapters open with a wall of
-- `import Mathlib.…`, so "what does this actually pull in?" is a daily
-- question whose only other answer is grepping .lake/packages.
map("<LocalLeader>mi", "<Cmd>LeanModuleImports<CR>", "Imports of this module")
map("<LocalLeader>mI", "<Cmd>LeanModuleImportedBy<CR>", "Modules importing this one")

-- ── \l · lemma search ─────────────────────────────────────────────────────
-- Three pickers that were already loaded and already working, reachable only
-- by typing their names. Workspace symbols is the best lemma-finder here and
-- was mentioned once, in passing, in the cheatsheet's lemma table.
--
-- \l AND NOT \s, WHICH WAS THE REQUESTED PREFIX: lean.nvim already owns \s
-- ("Accept the first infoview suggestion" — measured live, not inferred), and
-- it is the key that makes `exact?` and `rw?` worth using. Turning it into a
-- prefix does not merely add a timeoutlen stall: mini.clue drives <LocalLeader>
-- and its H.state_is_at_target() only fires when exactly ONE clue matches the
-- query (clue.lua:1507), so with \sl/\lw/\la present, \s alone would stop
-- executing at all and need a trailing <CR>. \l is free here and reads as
-- "lemma/lookup", which is what all three do.
map("<LocalLeader>ll", "<Cmd>Telescope loogle<CR>", "Loogle (by type pattern)")
map(
  "<LocalLeader>lw",
  "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>",
  "Workspace symbols (by name)"
)
map("<LocalLeader>la", "<Cmd>Telescope lean_abbreviations<CR>", "Unicode abbreviations")

-- Hints are ambient, so they need an off switch for when a line gets busy.
-- Buffer-scoped both ways: toggling here never touches another buffer.
map("<LocalLeader>h", function()
  local b = vim.api.nvim_get_current_buf()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = b }), { bufnr = b })
end, "Toggle inlay hints")

-- Open the rendered book page for this file (Mathematics in Lean ships one).
-- Inert with a warning in Lean projects that have no html/ build.
local book = require("config.lean.book")
map("<LocalLeader>b", book.open, "Open book page")
vim.api.nvim_buf_create_user_command(0, "LeanBook", book.open, {
  desc = "Open the rendered book page for this Lean file",
})

-- ── \y · yank this file's module name ─────────────────────────────────────
-- VS Code's `lean4.copyModuleName` (parity audit #10). `\y` rather than `\c`
-- ("clear all pins", lean.nvim's) or `\m` (already the module-hierarchy
-- group): this is a yank, and it is the only one in the Lean namespace.
--
-- Not `path − root`: see the header of config.lean.module_name for why a
-- mathlib buffer reports the MIL project root and needs its own rule.
local module_name = require("config.lean.module_name")
map("<LocalLeader>y", module_name.copy, "Yank module name")
vim.api.nvim_buf_create_user_command(0, "LeanCopyModuleName", module_name.copy, {
  desc = "Copy this file's dotted Lean module name to the clipboard",
})

-- Lean cheatsheet. Built as a scratch buffer rather than :edit-ing the file,
-- because the infoview window carries 'winfixbuf' and editing into it aborts
-- with E1513. Snacks.win already binds `q` to close.
map("<LocalLeader>?", function()
  local path = vim.fs.joinpath(vim.fn.stdpath("config"), "lean-cheatsheet.md")
  local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path)
    or { "# Lean cheatsheet", "", "Missing file: " .. path }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  -- Render the tables. markview's auto-attach skips buftype=nofile and this
  -- config suppresses it for markdown anyway, but an explicit attach is not
  -- filtered — same call <leader>tv makes. Set the toggle's flag too, so that
  -- keymap detaches rather than re-attaching if pressed inside the float.
  pcall(function()
    require("markview.actions").attach(buf)
    vim.b[buf]._markview_on = true
  end)
  Snacks.win({
    buf = buf,
    width = 0.8,
    height = 0.9,
    border = "rounded",
    title = " Lean cheatsheet ",
    title_pos = "center",
    wo = { wrap = false, number = false, signcolumn = "no", conceallevel = 2 },
    bo = { bufhidden = "wipe" },
  })
end, "Lean cheatsheet")
