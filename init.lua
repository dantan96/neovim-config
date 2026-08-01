-- Enable 24-bit RGB colors in the terminal
vim.opt.termguicolors = true

vim.o.guifont = "Fira Code:h14"

if vim.g.neovide then
  vim.g.neovide_scale_factor = 1.0

  local function change_font_size(delta)
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor + delta * 0.1
  end

  vim.keymap.set({ "n", "v", "i" }, "<D-=>", function()
    change_font_size(1)
  end, { desc = "Increase font size" })
  vim.keymap.set({ "n", "v", "i" }, "<D-->", function()
    change_font_size(-1)
  end, { desc = "Decrease font size" })
  vim.keymap.set({ "n", "v", "i" }, "<D-0>", function()
    vim.g.neovide_scale_factor = 1.0
  end, { desc = "Reset font size" })
end

-- auto-reload files when modified externally
-- https://unix.stackexchange.com/a/383044
vim.o.autoread = true
vim.api.nvim_create_autocmd(
  { "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" },
  {
    -- Grouped with clear=true so re-sourcing init.lua (<space><space>x)
    -- replaces this autocmd instead of stacking duplicates.
    group = vim.api.nvim_create_augroup("autoread-checktime", { clear = true }),
    command = "if mode() != 'c' | checktime | endif",
    pattern = { "*" },
  }
)

-- Setup spthy support with the streamlined module
-- (also registers the spthy/sapic filetypes)
pcall(function()
  require("config.spthy_setup").setup()
end)

-- Suppress deprecation warnings originating from third-party plugins.
-- Warnings from the user's own config are still shown.
local _deprecate = vim.deprecate
---@diagnostic disable-next-line: duplicate-set-field
vim.deprecate = function(name, alternative, version, plugin, backtrace)
  local trace = debug.traceback("", 2)
  if trace:find(vim.fn.stdpath("data") .. "/lazy/", 1, true) then
    return
  end
  _deprecate(name, alternative, version, plugin, backtrace)
end

-- Load lazy.nvim plugin manager
require("config.lazy")
require("config.fsharp.semantic_priority")
require("config.remark_auto").setup()
require("config.shebang").setup()
require("config.uv_init").setup()

-- General keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<space>x", "<cmd>:.lua<CR>", { desc = "Execute line as Lua" })
vim.keymap.set("v", "<space>x", "<cmd>:lua<CR>", { desc = "Execute selection as Lua" })

-- Basic editor settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.wrap = false
-- One-row bottom chrome: the command line appears only when summoned
-- (noice.nvim hosts cmdline UI in popups, the standard companion).
vim.opt.cmdheight = 0
-- ... and exactly ONE statusline, ever. The default laststatus=2 draws a
-- bar per window, so a bottom split (terminal, quickfix) stacks its own
-- bar on top of the screen-bottom one — the chrome reads 2-3 rows tall.
-- 3 = single global statusline; mini.statusline supports it natively and
-- the <leader>ts toggle below already restores this value.
vim.opt.laststatus = 3

-- Visual-line vertical motion: pairs with the visual-relative numbers rendered
-- by statuscol.nvim (lua/plugins/statuscol.lua). With these, a count like 3<j>
-- moves 3 *screen* rows, landing on the gutter row labelled 3 when wrap is on.
-- Normal + visual only; operator-pending is left native so dj/dk stay linewise.
vim.keymap.set({ "n", "x" }, "j", "gj", { desc = "Down by display line" })
vim.keymap.set({ "n", "x" }, "k", "gk", { desc = "Up by display line" })
-- No n/x arrow maps here: multicursor.nvim owns <Up>/<Down> in those modes
-- (add cursor above/below); it loads on VeryLazy and would shadow them
-- anyway. Insert mode keeps display-line arrows.
vim.keymap.set("i", "<Down>", "<C-o>gj", { desc = "Down by display line" })
vim.keymap.set("i", "<Up>", "<C-o>gk", { desc = "Up by display line" })

-- Toggle soft wrap (window-local), with prose-friendly linebreak/breakindent.
vim.keymap.set("n", "<leader>w", function()
  vim.wo.wrap = not vim.wo.wrap
  vim.wo.linebreak = vim.wo.wrap
  vim.wo.breakindent = vim.wo.wrap
  vim.notify("wrap " .. (vim.wo.wrap and "on" or "off"))
end, { desc = "Toggle soft wrap" })

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})


-- Formatting opt-outs by project: a .prettierignore at a project root
-- (e.g. ~/ResumeProject) defaults vim.b.disable_autoformat on for the
-- files it covers, silencing save AND pause formatting; <leader>tf
-- re-enables per buffer. Asks prettier itself — no hardcoded paths.
require("config.prettier_ignore").setup()

-- Terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    -- Window-local, NOT vim.opt: the global form re-asserted
    -- number/relativenumber for the whole session every time a terminal
    -- opened, silently undoing any global toggle.
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
  end,
})

local job_id = 0
local term_buf = -1
local function open_terminal()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 15)
  job_id = vim.bo.channel
  term_buf = vim.api.nvim_get_current_buf()
end

local function term_alive()
  return job_id ~= 0 and vim.api.nvim_buf_is_valid(term_buf)
end

-- <leader>T (not <leader>st): an st-family map would stall multicursor's
-- single-char <leader>s for timeoutlen on every press.
vim.keymap.set("n", "<leader>T", open_terminal, { desc = "Open terminal" })

vim.keymap.set("n", "<leader>r", function()
  if not term_alive() then
    open_terminal()
  end
  local filename_and_enter = '"./' .. vim.fn.expand("%") .. '"\r\n'
  vim.fn.chansend(job_id, { filename_and_enter })
end, { desc = "Run current file" })

-- Oil.nvim keymaps
vim.keymap.set("n", "<leader>-", "<cmd>Oil<CR>", { desc = "Oil file manager" })
vim.keymap.set("n", "<leader>vim", "<cmd>Oil ~/.config/nvim/<CR>", { desc = "Oil nvim config" })

-- Statusline keymaps
-- Global toggle: <leader>ts
vim.keymap.set("n", "<leader>ts", function()
  if vim.opt.laststatus:get() == 0 then
    vim.opt.laststatus = 3 -- or 2, whatever you prefer
    vim.g.ministatusline_disable = false
  else
    vim.opt.laststatus = 0
    vim.g.ministatusline_disable = true
  end
  vim.cmd("redrawstatus")
end, { desc = "Toggle mini.statusline (and bar)" })

-- Buffer-local toggle: <leader>tS
vim.keymap.set("n", "<leader>tS", function()
  vim.b.ministatusline_disable = not vim.b.ministatusline_disable
  vim.cmd("redrawstatus")
end, { desc = "Toggle mini.statusline (buffer)" })

-- General keymaps
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { noremap = true, silent = true, desc = "Paste from clipboard" })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { noremap = true, silent = true, desc = "Page down + center" })
vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { noremap = true, silent = true, desc = "Page up + center" })
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { noremap = true, silent = true, desc = "Yank to clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { noremap = true, silent = true, desc = "Delete to black hole" })
vim.keymap.set({ "n", "v" }, "<Esc><Esc>", "<Esc><Esc><cmd>nohlsearch<CR>", { noremap = true, silent = true, desc = "Clear search highlights" })
-- vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-N>")

-- Toggle diagnostics (buffer-local, no globals touched)
vim.keymap.set("n", "<leader>lx", function()
  local filter = { bufnr = 0 }
  local enabled = vim.diagnostic.is_enabled(filter)
  vim.diagnostic.enable(not enabled, filter)
end, { desc = "Toggle diagnostics (buffer)" })

-- Add TreeSitter info command
pcall(function()
  require("ts_info").setup()
end)

require("capture_report").setup({
  command = "CapRep", -- :CapRep
  keymap = "<leader>hc", -- press <leader>hc in normal mode
})
