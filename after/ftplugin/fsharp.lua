-- after/ftplugin/fsharp.lua
-- Thin entry point — all logic lives in lua/config/fsharp/*. This file
-- is re-sourced for EVERY F# buffer: buffer-local options, keymaps and
-- buffer commands run each time; the modules' setup() functions are
-- once-guarded internally.

-- Buffer-local options -------------------------------------------------
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4
vim.opt_local.autoindent = false
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

-- Comment/format options previously supplied by vim-fsharp's ftplugin
-- (the plugin was removed: archived upstream, regex syntax superseded by
-- treesitter). Neovim's runtime ships no fsharp ftplugin, so without
-- these `gc` commenting has no commentstring.
vim.opt_local.comments = ":///,://!,://"
vim.opt_local.commentstring = "// %s"
vim.opt_local.formatoptions:remove("t")
vim.opt_local.formatoptions:append("croqnlj")
vim.opt_local.suffixesadd:append(".fs")

-- Session-global machinery (each setup() is once-guarded) ---------------
require("config.fsharp.highlights").setup()
require("config.fsharp.du_refs").setup()
require("config.fsharp.constraints").setup()
require("config.fsharp.editorconfig").setup()
require("config.fsharp.splitter").setup()

local fsi = require("config.fsharp.fsi")
fsi.setup()

-- Per-buffer wiring ------------------------------------------------------
local bufnr = vim.api.nvim_get_current_buf()

-- LSP boot: run directly (this ftplugin IS the FileType hook) instead of
-- a nested FileType autocmd, which never fired for the first F# buffer
-- of a session and duplicated itself on every subsequent one.
require("config.fsharp.lsp").start(bufnr)

-- No matchadd for "::" here: window matches paint OVER treesitter, and
-- the cons operator is captured as @operator.cons.fsharp (pink) by
-- queries/fsharp/highlights.scm. Clean up matches from older sessions.
for _, id in ipairs(vim.w.fsharp_match_ids or {}) do
  pcall(vim.fn.matchdelete, id)
end
vim.w.fsharp_match_ids = nil

-- Buffer-local keymaps: set for every F# buffer, independent of LSP
-- attach state (they used to live inside the not-already-attached branch
-- of the LSP boot, so a re-sourced ftplugin could skip them).
-- Ex-command mapping so Visual gets :'<,'> automatically.
local map_opts = { buffer = bufnr, desc = "F# Interactive" }
vim.keymap.set("n", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Normal: current line (then move down)
vim.keymap.set("x", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Visual: current selection
vim.keymap.set("n", "<M-@>", fsi.toggle, map_opts)

-- Buffer-local :FSharpSplitStrings
require("config.fsharp.splitter").attach(bufnr)
