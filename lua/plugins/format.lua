-- lua/plugins/format.lua
return {
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = {
        timeout_ms = 2000,
      },
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "isort", "black" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        fsharp = { "fantomas" },

        markdown = { "remark" },
        ["markdown.mdx"] = { "remark" },
      },
      formatters = {
        black = {
          prepend_args = {
            "--line-length",
            "79",
            "--preview",
            "--enable-unstable-feature",
            "string_processing",
          },
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
