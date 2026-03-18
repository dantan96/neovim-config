-- lua/plugins/format.lua
return {
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = {
        timeout_ms = 2000,
        quiet = true, -- suppress "Formatters unavailable" when no formatter matches
      },
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        fsharp = { "fantomas" },

        markdown = { "remark", "prettier", stop_after_first = true },
        ["markdown.mdx"] = { "remark", "prettier", stop_after_first = true },
      },
      formatters = {
        -- remark-cli loads .remarkrc.mjs which imports remark-gfm etc. via ESM.
        -- Those packages must be installed in the project's node_modules; without
        -- them Node exits with a module-not-found error and conform shows a crash.
        -- This condition skips the formatter silently when they're absent.
        remark = {
          command = "remark",
          args = { "--no-color", "--quiet", "--frail" },
          stdin = true,
          condition = function(_, ctx)
            local found = vim.fs.find("node_modules", {
              path = ctx.dirname,
              upward = true,
              type = "directory",
              limit = 1,
            })
            if #found == 0 then return false end
            return vim.fn.isdirectory(found[1] .. "/remark-gfm") == 1
          end,
        },

        ruff_format = {
          prepend_args = { "--line-length", "79" },
        },
        stylua = {
          prepend_args = { "--column-width", "79" },
        },
        shfmt = {
          prepend_args = { "-i", "2", "-ci" }, -- 2-space indent, indent switch cases
        },

        -- You can also tweak fantomas defaults here. Example: longer timeout.
        fantomas = {
          -- leave stdin handling to Conform’s builtin for fantomas
          -- but we can tone down timeouts by raising conform.format() timeout instead
        },
      },
    },
    config = function(_, opts)
      local conform = require("conform")
      conform.setup(opts)
      -- ------------- Register our Lua formatter -------------
      -- This mirrors how builtin Lua formatters (e.g. trim_whitespace) are defined:
      --   format = function(self, ctx, lines, callback) ... end
      -- Reference: trim_whitespace.lua in conform.nvim.  (See GitHub)
      -- https://github.com/stevearc/conform.nvim/blob/master/lua/conform/formatters/trim_whitespace.lua
      vim.keymap.set({ "n", "v" }, "<leader>f", function()
        conform.format({
          lsp_fallback = true,
          async = false,
          timeout_ms = 4000, -- a bit more generous than 2000
        })
      end, { desc = "Format buffer (Conform)" })
    end,
  },
}
