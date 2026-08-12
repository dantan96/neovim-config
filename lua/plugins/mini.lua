-- lua/plugins/mini.lua
return {
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      -- Statusline: stock sections, two deliberate changes. (1) The
      -- location cluster is split into line and column boxes — separate
      -- groups so they render as two boxes, both painted with the mode
      -- color. (2) Narrow windows show the file tail instead of a
      -- mid-path %< amputation.
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
            -- Line and column boxes both ride the mode color, matching
            -- the mode chip; kept as two groups so they stay visually
            -- separate boxes. Bare numbers only.
            return sl.combine_groups({
              { hl = mode_hl, strings = { mode } },
              { hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics, lsp } },
              { hl = "MiniStatuslineFilename", strings = { "%t%m%r" } },
              "%<",
              "%=",
              { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
              { hl = mode_hl, strings = { search, "%l" } },
              { hl = mode_hl .. "Col", strings = { "%v" } },
            })
          end,
        },
      })
      -- Profile themes still restyle MiniStatuslineLocation; keep the
      -- neutral default link.
      vim.api.nvim_set_hl(
        0,
        "MiniStatuslineLocation",
        { link = "MiniStatuslineFileinfo", default = true }
      )
      -- Column box, per-profile: <Mode>Col groups default to the neutral
      -- Location styling (plain Ghostty and GhosttyXonsh keep their exact
      -- previous look); a profile theme may re-link them to the mode chip
      -- for full mode treatment (GhosttyNu does).
      for _, m in ipairs({ "Normal", "Insert", "Visual", "Replace", "Command", "Other" }) do
        vim.api.nvim_set_hl(0, "MiniStatuslineMode" .. m .. "Col", {
          link = "MiniStatuslineLocation",
          default = true,
        })
      end
      -- mini.operators, with `replace` moved off `gr`.
      --
      -- WHY: with the default prefix, operators.lua:726-734 runs
      --   if prefix == 'gr' and has('nvim-0.11') then
      --     remove_lsp_mapping('n', 'gra') ... 'gri' 'grn' 'grr' 'grt' 'grx'
      -- i.e. it DELETES Neovim's built-in LSP maps outright — it does not
      -- merely shadow them. Measured in a live Lean buffer before this change:
      -- grn/gra/gri/grt were UNMAPPED and grr was "Replace line". Every other
      -- filetype in this config lost the standard LSP vocabulary too; Lean was
      -- just where it was noticed, because Lean's textDocument/declaration
      -- returns the parser and elaborator of a symbol and has no substitute.
      --
      -- Changing the prefix is all that is needed: the deletion block is gated
      -- on `prefix == 'gr'`, and Neovim creates grn/gra/grr/gri/grt in
      -- runtime/lua/vim/_defaults.lua at startup, before any plugin loads. So
      -- not deleting them leaves the built-ins in place, with no re-binding
      -- here and none in the Lean ftplugin.
      --
      -- WHY `gR` AND NOT `<Leader>gr`, WHICH WAS THE FIRST CHOICE — two
      -- measured blockers, both fatal:
      --   1. gitsigns already maps <leader>gr (n and x) to "Reset hunk",
      --      BUFFER-LOCALLY in every buffer it attaches to (plugins/gitsigns.lua:39,43).
      --      Buffer-local maps beat global ones, so a global <leader>gr replace
      --      operator would be dead in every file in a git repo — i.e. almost
      --      everywhere.
      --   2. The line variant is derived as prefix .. last-char-of-prefix
      --      (operators.lua:743), so <Leader>gr implies <Leader>grr, and
      --      tests/test_keymap_ownership.lua's stall invariant forbids exactly
      --      that shape: a <leader>X map that is a strict prefix of a longer
      --      <leader>X… map. Any two-key leader prefix for an operator hits
      --      this, so it is not a matter of picking a different letter.
      -- `gR` costs Neovim's built-in Virtual Replace mode, keeps all three
      -- variants (gR operator, gRR line, gR visual), stays one shift-key from
      -- the old muscle memory, and touches no leader namespace.
      require("mini.operators").setup({
        replace = { prefix = "gR" },
      })
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
