-- lua/plugins/quicker.lua
-- Editable, prettier quickfix/loclist.
return {
  {
    "stevearc/quicker.nvim",
    ft = "qf",
    keys = {
      {
        "<leader>q",
        function() require("quicker").toggle() end,
        desc = "Toggle quickfix (quicker)",
      },
    },
    opts = {
      keys = {
        {
          ">",
          function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end,
          desc = "Expand quickfix context",
        },
        {
          "<",
          function() require("quicker").collapse() end,
          desc = "Collapse quickfix context",
        },
      },
    },
  },
}
