-- after/ftplugin/markdown.lua
-- Thin entry point — all logic lives in lua/config/markdown/*.

require("config.markdown.peek_auto").setup()

-- Guard: only register global commands/autocmds once
if vim.g._markdown_config_helper then
  return
end
vim.g._markdown_config_helper = true

require("config.markdown.config_ensure").setup()
require("config.markdown.math_delims").setup()
require("config.markdown.export").setup()
