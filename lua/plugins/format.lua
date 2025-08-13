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
        -- We'll add fsharp below in the config, after we register our Lua formatter
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

        -- You can also tweak fantomas defaults here. Example: longer timeout.
        fantomas = {
          -- leave stdin handling to Conform’s builtin for fantomas
          -- but we can tone down timeouts by raising conform.format() timeout instead
        },
      },
    },

    -- IMPORTANT: we register the Lua formatter AFTER setup()
    config = function(_, opts)
      local conform = require("conform")
      conform.setup(opts)

      -- ------------- Register our Lua formatter -------------
      -- This mirrors how builtin Lua formatters (e.g. trim_whitespace) are defined:
      --   format = function(self, ctx, lines, callback) ... end
      -- Reference: trim_whitespace.lua in conform.nvim.  (See GitHub)
      -- https://github.com/stevearc/conform.nvim/blob/master/lua/conform/formatters/trim_whitespace.lua
      conform.formatters.fsharp_string_splitter = {
        -- purely Lua-based
        format = function(self, ctx, lines, callback)
          -- Ensure we *always* create a log entry when the formatter runs
          local log_path = vim.fn.stdpath("state")
            .. "/fsharp_string_splitter.log"
          local stamp = os.date("!%Y-%m-%d %H:%M:%S")
          pcall(
            vim.fn.writefile,
            { string.format("[%s] ENTER format() buf=%d", stamp, ctx.buf) },
            log_path,
            "a"
          )

          -- Try the helper
          local ok, helpers = pcall(require, "custom.fsharp_helpers")
          if
            not ok
            or not helpers
            or type(helpers.split_long_strings_in_buffer) ~= "function"
          then
            pcall(vim.fn.writefile, {
              string.format(
                "[%s] require(custom.fsharp_helpers) failed: %s",
                stamp,
                tostring(helpers)
              ),
            }, log_path, "a")
            return callback(nil, lines) -- pass-through
          end

          -- Call your splitter; it should return a table of NEW LINES or nil
          local ok_run, new_lines =
            pcall(helpers.split_long_strings_in_buffer, ctx.buf)
          if not ok_run then
            pcall(vim.fn.writefile, {
              string.format(
                "[%s] split_long_strings_in_buffer error: %s",
                stamp,
                tostring(new_lines)
              ),
            }, log_path, "a")
            return callback(nil, lines)
          end

          if type(new_lines) == "table" then
            pcall(vim.fn.writefile, {
              string.format(
                "[%s] splitter changed buffer: %d lines",
                stamp,
                #new_lines
              ),
            }, log_path, "a")
            return callback(nil, new_lines)
          else
            pcall(
              vim.fn.writefile,
              { string.format("[%s] splitter made no changes", stamp) },
              log_path,
              "a"
            )
            return callback(nil, lines)
          end
        end,
      }

      -- Now wire it into the chain for F#
      -- Put the splitter first; Fantomas second.
      conform.formatters_by_ft.fsharp =
        { "fsharp_string_splitter", "fantomas" }

      -- Optional: provide a slower default when you *explicitly* format
      -- so Fantomas has more time on first run
      vim.keymap.set({ "n", "v" }, "<leader>f", function()
        conform.format({
          lsp_fallback = true,
          async = false,
          timeout_ms = 5000, -- a bit more generous than 2000
        })
      end, { desc = "Format buffer (Conform)" })
    end,
  },
}
