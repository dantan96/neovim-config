-- lua/plugins/noice.lua
return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    keys = {
      -- Message history / inspection. Under <leader>m (messages): <leader>n is
      -- taken by multicursor's "match next", so an <leader>n* prefix would stall
      -- it on timeoutlen.
      { "<leader>mh", function() require("noice").cmd("history") end, desc = "Noice history" },
      { "<leader>ml", function() require("noice").cmd("last") end, desc = "Noice last message" },
      { "<leader>md", function() require("noice").cmd("dismiss") end, desc = "Noice dismiss popups" },
      -- Scroll inside LSP hover/signature popups; fall through to <C-f>/<C-b> when none.
      {
        "<c-f>",
        function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end,
        mode = { "n", "i", "s" }, silent = true, expr = true, desc = "Scroll forward (noice popup)",
      },
      {
        "<c-b>",
        function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end,
        mode = { "n", "i", "s" }, silent = true, expr = true, desc = "Scroll back (noice popup)",
      },
      -- Redirect a cmdline's output into a noice popup (e.g. :hi, :map).
      {
        "<S-Enter>",
        function() require("noice").redirect(vim.fn.getcmdline()) end,
        mode = "c", desc = "Redirect cmdline to Noice",
      },
    },
    opts = {
      cmdline = {
        enabled = true,
        view = "cmdline_popup",
      },
      messages = { enabled = true },
      popupmenu = { enabled = true },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        progress = { enabled = true },
        hover = { enabled = true },
        signature = { enabled = true },
      },
    },
  },
}
