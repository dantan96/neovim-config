return {
  {
    "OXY2DEV/markview.nvim",
    -- Note: lazy.nvim uses `enabled` (not `enable`) to disable a plugin entirely.
    -- Leave Markview loaded so :Markview can be invoked manually;
    -- auto-start is suppressed in after/ftplugin/markdown.lua.
    -- lazy = false, -- author recommends not lazy-loading (it already manages its own)
    opts = {
      preview = {
        -- `lean` earns its place here for the injected markdown in `/-! -/`
        -- blocks (config.lean.prose). markview's refresh autocmds bail out on
        -- any filetype absent from this list, so a buffer attached by hand
        -- would draw once and then never update again. Attaching stays
        -- opt-in: \p toggles it, and only the generated MILbook/ tree starts
        -- it automatically.
        filetypes = { "markdown", "quarto", "rmd", "typst", "asciidoc", "lean" },
      },
    },
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
