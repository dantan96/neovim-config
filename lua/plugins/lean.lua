-- lua/plugins/lean.lua — Lean 4 (theorem prover) support.
--
-- lean.nvim owns the Lean language server itself: it ships its own
-- lsp/leanls.lua (toolchain lookup via elan, `lake serve`, Lean-specific
-- handlers) and calls vim.lsp.enable("leanls") from lean.init(). Nothing here
-- or in plugins/lsp.lua needs to enable it, and a competing lsp/leanls.lua
-- that redefined `cmd` or `root_dir` would break the way it starts the server.
--
-- Contributing extra CONFIG is a different thing and is done:
-- after/lsp/leanls.lua adds the experimental capability for the patched
-- server. vim.lsp.config resolution deep-merges every lsp/<name>.lua on the
-- runtimepath with after/ last, so that file adds to lean.nvim's rather than
-- replacing it — and it starts nothing, since only vim.lsp.enable does that.
-- Whether that capability is advertised at all is decided by
-- lua/config/lean/rich_tokens.lua, which also owns :LeanRichTokens.
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

-- Where lean.nvim comes from. On this machine it is a permanently local fork
-- (decisions.md D15); on WorkBox and main, which share this tree through
-- chezmoi, the fork does not exist and lazy fetches upstream as before. The
-- decision, the path and the existence test all live in one module so nothing
-- re-derives them — see lua/config/lean/fork.lua.
local fork = require("config.lean.fork")

local spec = {
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
        -- Always a side pane. The default is "auto", which only goes
        -- vertical when `columns > 2.5 * lines` (infoview.lua:442) — an
        -- aspect-ratio guess that lands on horizontal in an ordinary
        -- ~100x50 window and silently flips layout when the terminal is
        -- resized or the window is split. Pin it.
        orientation = "vertical",
        -- Goal states are wide (mathlib hypotheses run long), so give the
        -- infoview a fixed column count rather than a fraction of a window
        -- that may itself already be split.
        -- A FRACTION of total columns, not a fixed count. lean.nvim's
        -- `res_dim` (infoview.lua:233) reads any value < 1 as a proportion of
        -- `vim.o.columns`. 0.4 is ~55 columns at 137 -- the width the previous
        -- fixed value was tuned to. Tracked on resize by the autocmd below.
        width = 0.4,
        -- Only consulted for horizontal infoviews, which the pin above
        -- rules out; kept so removing the pin restores sane behaviour.
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

    -- :LeanRichTokens and the legend sniffing behind it. Set up here rather
    -- than in the plugin's `config`, for two reasons: after/lsp/leanls.lua
    -- asks this module whether to advertise the capability, and that file is
    -- read the moment lean.nvim calls vim.lsp.enable("leanls") — before any
    -- `config` function would have run; and `:LeanRichTokens status` should
    -- answer from a scratch buffer, not only after a .lean file has been
    -- opened. `init` runs at startup, which satisfies both. Must precede the
    -- line below for the first of those reasons.
    -- Make the fractional `infoview.width` above track the terminal.
    -- Upstream resolves the fraction once, at infoview creation
    -- (infoview.lua:400); its only VimResized handler re-renders pin CONTENT
    -- (tui.lua:1204) without touching the window, and the window carries
    -- `winfixwidth` (infoview.lua:930) so Neovim will not equalise it either.
    -- Without this the width is right at startup and permanently wrong after
    -- the first resize. Verified live: 80 -> 120 columns moves it 32 -> 48;
    -- deleting this autocmd leaves it at 32 while the code window grows.
    --
    -- In `init` rather than the ftplugin: tests/test_invariants.lua asserts a
    -- re-source changes no autocmd population.
    vim.api.nvim_create_autocmd("VimResized", {
      group = vim.api.nvim_create_augroup("LeanInfoviewWidth", { clear = true }),
      desc = "Re-resolve the Lean infoview's fractional width",
      callback = function()
        local ok, iv = pcall(require, "lean.infoview")
        if ok and type(iv.reposition) == "function" then
          pcall(iv.reposition)
        end
      end,
    })

    require("config.lean.rich_tokens").setup()

    -- Occurrence highlighting, which the server has always been able to
    -- serve and nothing ever asked for. Set up here rather than in
    -- after/ftplugin/lean.lua because it is autocmds, and that file must
    -- define none — it re-runs on every :edit, and
    -- tests/test_invariants.lua asserts the autocmd population is unchanged
    -- by a re-source. `init` runs at startup, before lean.nvim itself
    -- loads, which is early enough for the module's LspAttach hook to see
    -- the first Lean file of the session.
    -- Pasteable setup info: OS/arch, tool versions, project path and the
    -- installed-toolchain list as one Markdown block. `:LeanSetupInfo`, not a
    -- `:checkhealth lean` section -- `health.lua` is lean.nvim's OWN module
    -- and a section there would shadow a plugin namespace.
    require("config.lean.setup_info").setup()

    require("config.lean.document_highlight").setup()

    -- Namespace components, module paths and the keyword split. Same
    -- placement and the same reason as document_highlight: it is autocmds
    -- (LspTokenUpdate and ColorScheme), and after/ftplugin/lean.lua must
    -- define none. It must also exist before the first Lean file is drawn,
    -- because after/syntax/lean.vim links into the groups it owns.
    require("config.lean.namespace_hl").setup()
  end,

  config = function()

    -- Abbreviations outside Lean buffers. Two things, both explained in

    -- lua/config/lean/abbreviations.lua: `\to` expands in telescope prompts

    -- (parity #40), and lean.nvim's `abbreviations.load()` is patched so

    -- `\la` stops throwing -- upstream resolves its JSON with

    -- `debug.getinfo(2)`, the CALLER's frame, which is wrong for every

    -- caller outside `lua/lean/`. That key was recorded as working while it

    -- threw on every press.

    --

    -- Here rather than `init`: both need lean.nvim itself, and this runs

    -- exactly when it loads.

    require("config.lean.abbreviations").setup()

    -- Three lean.nvim defects this config used to patch from the outside.
    -- They are real in-tree fixes in the fork now (FORK-CHANGES.md M1–M3);
    -- this call is a no-op there and reapplies the old wrappers on machines
    -- that fell back to upstream. Must run before anything requires
    -- lean.satellite or builds the Loogle picker.
    require("config.lean.fork").warn_if_missing()

    -- ── satellite.nvim: whole-file elaboration progress ─────────────────
    -- lean.nvim ships lua/lean/satellite.lua, a Satellite.Handler plotting
    -- lean.progress onto the whole-document scrollbar — the thing the sign
    -- column cannot do, because signs only exist for visible lines. Nothing
    -- inside lean.nvim requires it (`grep -rn 'lean.satellite' lua/ plugin/`
    -- in the plugin matches only its own header), so it is inert until asked
    -- for. Requiring it here loads satellite as a side effect, which is the
    -- correct order: satellite.handlers.init() runs at the FIRST RENDER and
    -- only calls setup() on handlers registered before that point.
    --
    -- The setup() call afterwards is for the other order — satellite already
    -- rendered once (it loads on VeryLazy) before the session's first Lean
    -- file. Without it lean's handler is registered but never set up, which
    -- costs the `leanProgressBar` highlight (so the marks are invisible) and
    -- the progress-event refresh. Running it twice is harmless: the function
    -- is a `nvim_create_augroup(..., {})` — i.e. clearing — plus a
    -- tbl_deep_extend onto its own config.

    -- The satellite shim that used to sit here is now a real in-tree fix in
    -- the fork (FORK-CHANGES.md M3) and, for machines without it, lives in
    -- makes.

    local has_satellite, sat = pcall(require, "satellite.handlers")
    if has_satellite then
      pcall(require, "lean.satellite")
      for _, handler in ipairs(sat.handlers or {}) do
        if handler.name == "lean.nvim" and handler.setup then
          pcall(
            handler.setup,
            require("satellite.config").user_config.handlers["lean.nvim"] or {},
            require("satellite.view").schedule_refresh
          )
        end
      end
    end
  end,
}

-- The pin itself. Assigned rather than always-present-and-maybe-nil: lazy.nvim
-- tells a managed plugin from a local one by whether the `dir` key exists at
-- all, so a nil value is not the same as no key.
if fork.enabled() then
  spec.dir = fork.dir()
end

return { spec }
