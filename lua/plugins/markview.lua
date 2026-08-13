return {
  {
    "OXY2DEV/markview.nvim",
    -- Note: lazy.nvim uses `enabled` (not `enable`) to disable a plugin entirely.
    -- Leave Markview loaded so :Markview can be invoked manually;
    -- auto-start is suppressed in after/ftplugin/markdown.lua.
    -- lazy = false, -- author recommends not lazy-loading (it already manages its own)
    opts = {
      preview = {
        -- Attach and refresh are decided per BUFFER, not per filetype.
        --
        -- Filetype gating cannot express what is wanted here. markview's
        -- autocmds service exactly the filetypes in `preview.filetypes`, so
        -- adding `lean` (needed for the injected markdown in `/-! -/` blocks —
        -- otherwise an attached buffer draws once and never updates, GOTCHAS
        -- B16) also makes markview attach to EVERY Lean buffer of its own
        -- accord. Measured: opening a MILbook file and then a Mathlib one drew
        -- 154 extmarks over Mathlib's docstrings. Detaching from the ftplugin
        -- afterwards loses the race — the flag read `off` while the marks were
        -- on screen.
        --
        -- A `condition` short-circuits the filetype list entirely (see
        -- markview/autocmds.lua: the ft checks run only `if condition == nil`),
        -- and is consulted for refresh as well as attach. So the rule is simply
        -- "this buffer asked for it", which is also what restores markdown's
        -- pre-existing behaviour: before `lean` pulled markview in, markdown
        -- never auto-started either, because the plugin was never loaded.
        --
        -- Must return an explicit boolean: markview treats a nil return as
        -- "no condition set" and falls back to the filetype list.
        condition = function(buf)
          if not vim.api.nvim_buf_is_valid(buf) then
            return false
          end
          if vim.bo[buf].filetype == "lean" then
            return vim.b[buf].lean_prose_on == true
          end
          return vim.b[buf]._markview_on == true
        end,
        -- `lean` is deliberately NOT in this list, and that is the safety net
        -- rather than an oversight. `spec.get` evaluates `condition` through a
        -- guarded call, so anything that goes wrong inside it yields `nil` —
        -- which markview reads as "no condition set" and falls straight through
        -- to this list. Measured: with `lean` present, a Mathlib buffer whose
        -- condition returned false was still attached from bufHandle and drew
        -- 154 extmarks over its docstrings. With it absent, the fallback path
        -- can only decline. The failure mode is "prose does not render", never
        -- "conceal appears in a file Dan is writing proofs in".
        filetypes = { "markdown", "quarto", "rmd", "typst", "asciidoc" },
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
            vim.b[buf]._markview_on = false
            pcall(mv.detach, buf)
          else
            -- Flag first: preview.condition above reads it to decide whether
            -- this buffer may be attached and refreshed.
            vim.b[buf]._markview_on = true
            pcall(mv.attach, buf)
          end
        end,
        ft = "markdown",
        desc = "Toggle Markview (attach on first use)",
      },
    },
  },
}
