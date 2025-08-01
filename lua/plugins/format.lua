-- lua/plugins/format.lua
return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- Run the formatter on save *only* if the client itself can’t format
      format_on_save = {
        timeout_ms = 2000,
      },
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "black", "isort" },
        fsharp = { "fantomas" },
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
      },
    },
  },
}
