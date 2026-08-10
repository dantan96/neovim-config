-- after/ftplugin/markdown.lua
-- Thin entry point — all logic lives in lua/config/markdown/*.

require("config.markdown.peek_auto").setup()

-- Buffer-local options: must run for EVERY markdown buffer, so keep
-- them above the once-guard below.
-- textwidth is the gq/colorcolumn guide and must match prettier's
-- --print-width (lua/plugins/format.lua). Vim's native live wrap must
-- stay OFF ('t' is added by $VIMRUNTIME/ftplugin/markdown.vim): with
-- textwidth set it would wrap at 65 as you type, splitting `backtick
-- spans` and code-block lines prettier would never touch. Live
-- formatting is instead conform-on-pause (config.markdown.pauseformat).
vim.opt_local.textwidth = 65
vim.opt_local.formatoptions:remove("t")
vim.opt_local.formatoptions:remove("a")
vim.opt_local.colorcolumn = "+1"

-- Format-on-pause: debounce wiring + <leader>tw toggle.
require("config.markdown.pauseformat").attach()

-- Guard: only register global commands/autocmds once
if vim.g._markdown_config_helper then
  return
end
vim.g._markdown_config_helper = true

require("config.markdown.config_ensure").setup()
require("config.markdown.math_delims").setup()
require("config.markdown.export").setup()
require("config.markdown.pauseformat").setup()
