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

      -- Keymap hints. A trigger only *shows* the clue window after
      -- `window.delay`; complete maps (e.g. multicursor's single-char
      -- <leader>n) still fire instantly, so this adds no timeoutlen-style
      -- stalls.
      local miniclue = require("mini.clue")
      miniclue.setup({
        triggers = {
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "'" },
          { mode = "n", keys = "`" },
          { mode = "n", keys = '"' },
          { mode = "x", keys = '"' },
          { mode = "n", keys = "<C-w>" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
        },
        clues = {
          miniclue.gen_clues.builtin_completion(),
          miniclue.gen_clues.g(),
          miniclue.gen_clues.marks(),
          miniclue.gen_clues.registers(),
          miniclue.gen_clues.windows(),
          miniclue.gen_clues.z(),
        },
        window = { delay = 500 },
      })
    end,
  },
}
