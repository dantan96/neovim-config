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

-- Indent width must match prettier's list indentation, for the same
-- reason textwidth matches --print-width: prettier indents a nested
-- list item to its parent's *content offset* ("- " = 2), so the global
-- shiftwidth/softtabstop of 4 (init.lua) makes >> and <Tab> disagree
-- with every format-on-save/pause run. Worse than cosmetic: 4 per
-- level is legal CommonMark only by 2 spaces of slack, so one extra >>
-- lands the line 6+ past the parent marker, where it stops being a
-- list item and becomes a lazy continuation of the parent's paragraph
-- — prettier then merges it into the parent line and the bullet is
-- gone. (The mirror fix, prettier --tab-width 4, also works but would
-- put this config's markdown out of step with stock prettier.)
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2

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
