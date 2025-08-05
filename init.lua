-- Enable 24-bit RGB colors in the terminal
vim.opt.termguicolors = true

-- Set up filetype detection for Tamarin files - do this as early as possible
vim.filetype.add({
  extension = {
    spthy = "spthy",
    sapic = "spthy",
  },
})

-- log("Registered Tamarin filetype")

-- Setup spthy support with the streamlined module
pcall(function()
  require("config.spthy_setup").setup()
end)

-- Load lazy.nvim plugin manager
require("config.lazy")
require("config.fsharp-highlights")

-- General keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<space>x", "<cmd>:.lua<CR>")
vim.keymap.set("v", "<space>x", "<cmd>:lua<CR>")

-- Basic editor settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.wrap = false

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    vim.opt.modifiable = true
    vim.opt.number = true
    vim.opt.relativenumber = true
  end,
})

local job_id = 0
function open_terminal()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 15)
  job_id = vim.bo.channel
end

vim.keymap.set("n", "<leader>st", open_terminal)

vim.keymap.set("n", "<leader>r", function()
  if job_id == 0 then
    open_terminal()
  end
  local filename_and_enter = '"./' .. vim.fn.expand("%") .. '"\r\n'
  vim.fn.chansend(job_id, { filename_and_enter })
end)

-- Oil.nvim keymaps
vim.keymap.set("n", "<leader>-", "<cmd>Oil<CR>")
vim.keymap.set("n", "<leader>vim", "<cmd>Oil ~/.config/nvim/<CR>")

-- General keymaps
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<Esc><Esc>", "<Esc><cmd>nohlsearch<CR><Esc>", { noremap = true, silent = true })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-N>")

-- Toggle diagnostics
-- local isLspDiagnosticsVisible = true
-- vim.keymap.set("n", "<leader>lx", function()
--   isLspDiagnosticsVisible = not isLspDiagnosticsVisible
--   vim.diagnostic.config({
--     virtual_text = isLspDiagnosticsVisible,
--     underline = isLspDiagnosticsVisible,
--     scope = "buffer",
--   }, nil, 0)
-- end)

-- Toggle diagnostics (buffer-local, no globals touched)
vim.keymap.set("n", "<leader>lx", function()
  local filter = { bufnr = 0 } -- 0 = current buffer
  local enabled = vim.diagnostic.is_enabled(filter) -- check current state
  vim.diagnostic.enable(not enabled, filter) -- flip it
end, { desc = "Toggle diagnostics (buffer)" })

-- Add TreeSitter info command
pcall(function()
  require("ts_info").setup()
end)

require("capture_report").setup({
  command = "CapRep", -- :CapRep
  keymap = "<leader>hc", -- press <leader>hc in normal mode
})
