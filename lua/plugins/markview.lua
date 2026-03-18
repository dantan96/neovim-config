return {
  {
    "OXY2DEV/markview.nvim",
    -- Note: lazy.nvim uses `enabled` (not `enable`) to disable a plugin entirely.
    -- Leave Markview loaded so :Markview can be invoked manually;
    -- auto-start is suppressed in after/ftplugin/markdown.lua.
    -- lazy = false, -- author recommends not lazy-loading (it already manages its own)
    keys = {
      {
        "<leader>tv",
        function()
          local buf = vim.api.nvim_get_current_buf()
          -- Must call Lua API directly: vim.cmd passes args as strings, but
          -- markview's state.buf_safe() rejects non-number buffer ids silently.
          local mv = require("markview.actions")
          if vim.b[buf]._markview_on then
            pcall(mv.detach, buf)
            vim.b[buf]._markview_on = false
          else
            pcall(mv.attach, buf)
            vim.b[buf]._markview_on = true
          end
        end,
        ft = "markdown",
        desc = "Toggle Markview (attach on first use)",
      },
    },
  },
}
