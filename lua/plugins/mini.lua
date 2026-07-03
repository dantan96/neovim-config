-- lua/plugins/mini.lua
return {
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require("mini.statusline").setup()
      require("mini.operators").setup()
      require("mini.ai").setup({
        custom_textobjects = {
          -- Disable mini.ai's af/if (function call) in favor of
          -- treesitter-textobjects' af/if (function definition).
          f = false,
        },
      })
    end,
  },
}
