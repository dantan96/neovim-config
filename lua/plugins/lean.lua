-- lua/plugins/lean.lua — Lean 4 (theorem prover) support.
--
-- lean.nvim owns the Lean language server itself: it locates the toolchain
-- through elan and starts leanls per project. That is why there is
-- deliberately NO lsp/leanls.lua and no vim.lsp.enable("leanls") in
-- plugins/lsp.lua — either would start a second, competing client.
--
-- No treesitter parser is installed for Lean on purpose: tree-sitter-lean is
-- unfinished and absent from nvim-treesitter's `main` registry, so adding
-- "lean" to ensure_installed would make ts.install() retry on every startup.
-- Highlighting comes from the runtime syntax file plus the server's semantic
-- tokens (26 token extmarks observed on a mathlib buffer; the legend carries
-- Lean's own `leanSorryLike` type).
--
-- Abbreviations (insert-mode `\to` → `→`) use `\` as their leader, which is
-- also maplocalleader. They do not contend: expansion is insert-mode only,
-- while the <LocalLeader> mappings are normal-mode.

return {
  {
    "Julian/lean.nvim",
    event = { "BufReadPre *.lean", "BufNewFile *.lean" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim", -- :Telescope loogle
    },
    -- Configured through vim.g.lean_config in `init`, NOT lazy's `opts`.
    -- lean.nvim self-activates on load and reads this global; `opts` would make
    -- lazy call require("lean").setup(), which is deprecated and warns:
    --   "require(\"lean\").setup is deprecated, use vim.g.lean_config instead.
    --    Feature will be removed in lean.nvim v2026.9.1"
    -- `init` runs at startup, before the plugin loads on the event below, so
    -- the global is in place by the time lean.nvim reads it.
    --
    -- blink.cmp's capabilities reach this server without being named here:
    -- plugins/lsp.lua applies them via vim.lsp.config("*"), and lean.nvim
    -- starts leanls through vim.lsp, so the "*" defaults merge in. Verified
    -- by diffing the live client's completionList capability against
    -- require("blink.cmp").get_lsp_capabilities() — they match exactly.
    init = function()
      vim.g.lean_config = {
        mappings = true,

        infoview = {
          autoopen = true,
          -- Goal states are wide (mathlib hypotheses run long), so give the
          -- infoview a fixed column count rather than a fraction of a window
          -- that may itself already be split.
          width = 55,
          horizontal_position = "bottom",
          indicators = "auto",
        },

        lsp = {
          enhanced_handlers = { hover = true, diagnostics = true },
          init_options = {
            editDelay = 10,
            hasWidgets = true,
          },
        },

        abbreviations = {
          enable = true,
          leader = "\\",
        },

        -- Widget graphics render through the Kitty protocol, which Ghostty
        -- speaks. SVG output additionally needs resvg on PATH (installed via
        -- brew); raster images work without it.
        graphics = { enabled = true },

        goal_markers = { unsolved = " ⚒ ", accomplished = "🎉" },
        progress_bars = { enable = true },
        stderr = { enable = true },
      }
    end,
  },
}
