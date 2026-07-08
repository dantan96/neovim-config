-- after/ftplugin/markdown.lua
-- Thin entry point — all logic lives in lua/config/markdown/*.

require("config.markdown.peek_auto").setup()

-- Buffer-local options: must run for EVERY markdown buffer, so keep
-- them above the once-guard below.
-- textwidth is the gq/colorcolumn guide and must match prettier's
-- --print-width (lua/plugins/format.lua), which does the actual
-- hard-wrapping on save. Live wrap while typing is OFF by default
-- (hardwrap.attach() strips the 'a'/'t' flags, including the 't' the
-- runtime ftplugin adds); 'w' only matters when live wrap is toggled
-- on, and is kept so toggled-on behaviour keeps trailing-blank
-- paragraph semantics.
vim.opt_local.textwidth = 65
vim.opt_local.formatoptions:append("w")
vim.opt_local.colorcolumn = "+1"

-- Live hard-wrap toggle: enforce this buffer's saved choice (a :e
-- reload re-runs ftplugins) and map <leader>tw / :HardWrapToggle.
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
