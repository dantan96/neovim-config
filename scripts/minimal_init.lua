-- Minimal init for running tests with mini.test.
-- Loads only the config rtp and mini.nvim — no lazy.nvim, no plugins.

vim.opt.rtp:prepend(vim.fn.stdpath("config"))
vim.opt.rtp:prepend(vim.fn.expand("~/.local/share/nvim/lazy/mini.nvim"))

require("mini.test").setup()
