-- lua/plugins/satellite.lua — a decorated scrollbar in a floating window.
--
-- Installed for two VS Code-parity rows at once (research/11-vscode-parity.md
-- #60, #61), both of which lean.nvim has already written the hard half of:
--
--   * WHOLE-FILE ELABORATION PROGRESS. lean.nvim draws its progress bars in the
--     sign column, which by construction only covers the lines currently on
--     screen — you cannot see that the 300 lines below the fold are still
--     being elaborated. lean.nvim ships lua/lean/satellite.lua, a
--     Satellite.Handler that plots `lean.progress` onto the whole-document
--     bar. NOTHING REQUIRES IT: `grep -rn "lean.satellite" lua/ plugin/` in
--     lean.nvim matches only the module's own header line, so the handler is
--     inert until something asks for it. lua/plugins/lean.lua's config does.
--
--   * THE DIAGNOSTIC SCROLLBAR — VS Code's red/orange bands showing where the
--     errors are in the part of the file you are not looking at
--     (manual.md:175). That is satellite's own stock `diagnostic` handler.
--
-- Loaded at startup rather than on `ft`: handlers register into satellite at
-- require time, so satellite must exist before lean.nvim's config runs. It is
-- a small plugin and draws nothing until a buffer has something to show.
return {
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    -- setup() alone is not enough, and the shortfall is invisible until you
    -- look for it. satellite loads its builtin handlers and calls their
    -- setup() from handlers.init(), which runs lazily AT THE FIRST RENDER
    -- (handlers.lua:169-191). The diagnostic handler keeps its own cache and
    -- fills it ONLY from a `DiagnosticChanged` autocmd created in that setup
    -- (handlers/diagnostic.lua:59-67), so any diagnostic that arrived before
    -- the first render is never recorded and never plotted.
    --
    -- That is the normal case for Lean, not an edge case: open a file with
    -- errors in it and the server publishes them while you are still looking
    -- at the first screen. MEASURED before this line existed — one error
    -- diagnostic in the buffer, `satellite.Handler.diagnostic marks=0` on the
    -- bar. Forcing init() at startup puts the autocmd in place first.
    --
    -- lean.nvim's handler cannot be covered this way, because it does not
    -- exist yet at VeryLazy; lua/plugins/lean.lua calls its setup by hand for
    -- the same reason.
    config = function(_, opts)
      require("satellite").setup(opts)
      require("satellite.handlers").init()
    end,
    opts = {
      -- Only the focused window gets a bar. With the infoview open there are
      -- always at least two windows, and a scrollbar on a rendered goal state
      -- is decoration without information.
      current_only = true,
      winblend = 50,
      -- lean.nvim's own panes. A scrollbar over a rendered goal state or over
      -- the server's stderr tail is decoration with nothing to report, and
      -- with current_only it would appear the moment `\<Tab>` moves you there.
      excluded_filetypes = { "leaninfo", "leanstderr" },
      handlers = {
        -- Cursor position: redundant next to 'relativenumber', which this
        -- config has on, and it is the widest of the stock marks.
        cursor = { enable = false },
        -- The two that earn the plugin.
        diagnostic = { enable = true },
        -- Search and git hunks are free, and the config already has gitsigns.
        search = { enable = true },
        gitsigns = { enable = true },
        marks = { enable = false },
        quickfix = { enable = false },
      },
    },
  },
}
