-- lua/plugins/gitsigns.lua
-- Git hunk signs, navigation, staging and blame. Signs render in the
-- statuscol.nvim sign segment (namespace ".*", auto-hidden when empty);
-- catppuccin's gitsigns integration is already enabled in themes.lua.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- Keymaps are buffer-local, only in buffers gitsigns attaches to.
      -- <leader>g* is safe: no single-char <leader>g map exists (the
      -- other <leader>g* maps — multicursor's gv, snacks' gg — are all
      -- multi-char, so nothing stalls on timeoutlen).
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Navigation (]c/[c fall through to diff-mode behavior)
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next git hunk")
        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Prev git hunk")

        -- Hunk operations. stage_hunk TOGGLES: running it on a staged
        -- hunk unstages it (undo_stage_hunk is deprecated upstream).
        map("n", "<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("v", "<leader>gs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage/unstage selected lines")
        map("v", "<leader>gr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected lines")
        map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")

        -- Blame / diff
        map("n", "<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame line")
        map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
        map("n", "<leader>gd", gs.diffthis, "Diff against index")

        -- Hunk text object
        map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
      end,
    },
  },
}
