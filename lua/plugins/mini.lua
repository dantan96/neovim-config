-- lua/plugins/mini.lua
return {
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      -- Statusline: stock sections, two deliberate changes. (1) The
      -- location cluster gets its OWN group (MiniStatuslineLocation) —
      -- stock mini paints it with the mode color, which reads as three
      -- disconnected mode-colored boxes. Default-links to Fileinfo
      -- (neutral); profile themes may restyle it. (2) Narrow windows show
      -- the file tail instead of a mid-path %< amputation.
      local sl = require("mini.statusline")
      sl.setup({
        content = {
          active = function()
            local mode, mode_hl = sl.section_mode({ trunc_width = 120 })
            local git = sl.section_git({ trunc_width = 40 })
            local diff = sl.section_diff({ trunc_width = 75 })
            local diagnostics = sl.section_diagnostics({ trunc_width = 75 })
            local lsp = sl.section_lsp({ icon = "LSP", trunc_width = 75 })
            -- Filename: the bare untruncated name, always ("%t"). The "%<"
            -- truncation point sits AFTER it, so when space runs out the
            -- right-hand clusters get cut — the name itself never renders
            -- as an amputated "<rofile.lua".
            local fileinfo = sl.section_fileinfo({ trunc_width = 120 })
            local search = sl.section_searchcount({ trunc_width = 75 })
            -- Line box rides the mode color (the decoupling experiment is
            -- over); the column box is its own group for a two-tone pair.
            -- Bare numbers only.
            return sl.combine_groups({
              { hl = mode_hl, strings = { mode } },
              { hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics, lsp } },
              { hl = "MiniStatuslineFilename", strings = { "%t%m%r" } },
              "%<",
              "%=",
              { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
              { hl = mode_hl, strings = { search, "%l" } },
              { hl = "MiniStatuslineLocation", strings = { "%v" } },
            })
          end,
        },
      })
      vim.api.nvim_set_hl(
        0,
        "MiniStatuslineLocation",
        { link = "MiniStatuslineFileinfo", default = true }
      )
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
          miniclue.gen_clues.square_brackets(),
          miniclue.gen_clues.windows(),
          miniclue.gen_clues.z(),
        },
        window = { delay = 500 },
      })
    end,
  },
}
