-- after/ftplugin/markdown.lua
-- Thin entry point — all logic lives in lua/config/markdown/*.

require("config.markdown.peek_auto").setup()

-- Buffer-local options: must run for EVERY markdown buffer, so keep
-- them above the once-guard below.
vim.opt_local.textwidth = 65
vim.opt_local.formatoptions:append("aw")
vim.opt_local.colorcolumn = "+1"

-- Hard-wrap toggle: re-assert this buffer's saved on/off choice (a
-- :e reload re-runs ftplugins) and map <leader>tw / :HardWrapToggle.
require("config.markdown.hardwrap").attach()

-- Guard: only register global commands/autocmds once
if vim.g._markdown_config_helper then
  return
end
vim.g._markdown_config_helper = true

require("config.markdown.config_ensure").setup()
require("config.markdown.math_delims").setup()
require("config.markdown.export").setup()
require("config.markdown.hardwrap").setup()
