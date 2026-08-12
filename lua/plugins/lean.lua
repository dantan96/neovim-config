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
          -- Always a side pane. The default is "auto", which only goes
          -- vertical when `columns > 2.5 * lines` (infoview.lua:442) — an
          -- aspect-ratio guess that lands on horizontal in an ordinary
          -- ~100x50 window and silently flips layout when the terminal is
          -- resized or the window is split. Pin it.
          orientation = "vertical",
          -- Goal states are wide (mathlib hypotheses run long), so give the
          -- infoview a fixed column count rather than a fraction of a window
          -- that may itself already be split.
          width = 55,
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
      require("config.lean.rich_tokens").setup()

      -- Occurrence highlighting, which the server has always been able to
      -- serve and nothing ever asked for. Set up here rather than in
      -- after/ftplugin/lean.lua because it is autocmds, and that file must
      -- define none — it re-runs on every :edit, and
      -- tests/test_invariants.lua asserts the autocmd population is unchanged
      -- by a re-source. `init` runs at startup, before lean.nvim itself
      -- loads, which is early enough for the module's LspAttach hook to see
      -- the first Lean file of the session.
      require("config.lean.document_highlight").setup()

      -- Namespace components, module paths and the keyword split. Same
      -- placement and the same reason: it is autocmds (LspTokenUpdate and
      -- ColorScheme), and after/ftplugin/lean.lua must define none. It also
      -- has to be defined before the first Lean file is drawn, because
      -- after/syntax/lean.vim links into the highlight groups it owns.
      require("config.lean.namespace_hl").setup()
    end,

    -- Workaround for an upstream crash in `:Telescope loogle`.
    --
    -- lean/loogle.lua's search() returns `nil, err` when Loogle rejects a
    -- query. lean.nvim's telescope finder only turns that into `{}` when
    -- `#prompt > 4`; for a shorter prompt both guard branches are skipped and
    -- it returns the nil straight into telescope, which calls ipairs() on it:
    --
    --   finders.lua:144: bad argument #1 to 'ipairs' (table expected, got nil)
    --
    -- The finder runs per keystroke, so this fires as soon as you type a short
    -- prefix Loogle cannot parse — i.e. almost immediately. Verified directly:
    -- loogle.search("abc") returns nil plus "unknown identifier 'abc'", while
    -- "Nat" and "List.map" return tables.
    --
    -- Wrapping search() rather than the finder keeps the fix to one function
    -- and leaves the notify/empty behaviour for long prompts untouched. The
    -- pcall also covers search()'s error() on a non-200 status, which would
    -- otherwise propagate out of the finder. Remove once upstream returns a
    -- table unconditionally.
    config = function()
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
      --
      -- AND A SHIM, because lean.nvim's handler does not currently run at all
      -- against satellite's `main`. lean/satellite.lua:68 opens update() with
      --
      --     local pred = async.winbuf_pred(bufnr, winid)
      --
      -- but satellite moved winbuf_pred from `satellite.async` to
      -- `satellite.util` in its commit fc9672c ("refactor: update async lib to
      -- newer conventions") — its own diagnostic handler calls
      -- `util.winbuf_pred` (handlers/diagnostic.lua:96). So the field is nil and
      -- every render throws:
      --
      --     vim.schedule callback: .../lean/satellite.lua:68:
      --       attempt to call field 'winbuf_pred' (a nil value)
      --
      -- Measured that way, not guessed: the traceback appeared in :messages the
      -- moment a buffer long enough to need a scrollbar was opened, and the
      -- handler's mark count sat at 0 throughout. Restoring the name onto the
      -- module table is enough — lean/satellite.lua holds `async` as an upvalue
      -- and indexes the field at call time, so this reaches it whichever module
      -- loaded first. Guarded, so it disappears the day upstream fixes it.
      --
      -- The one thing not restored is the early abort: `async.ipairs` now takes
      -- a single argument, so the `pred` lean passes as a second one is ignored
      -- and its loop runs to completion instead of bailing when the buffer
      -- changes underneath it. Harmless — the marks are recomputed on the next
      -- render anyway — and not something to paper over from here.
      local has_async, satellite_async = pcall(require, "satellite.async")
      if has_async and satellite_async.winbuf_pred == nil then
        local has_util, satellite_util = pcall(require, "satellite.util")
        if has_util and type(satellite_util.winbuf_pred) == "function" then
          satellite_async.winbuf_pred = satellite_util.winbuf_pred
        end
      end

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

      local ok, loogle = pcall(require, "lean.loogle")
      if not ok or type(loogle.search) ~= "function" then
        return
      end
      local search = loogle.search
      loogle.search = function(...)
        local called, results, err = pcall(search, ...)
        if not called then
          return {}, tostring(results)
        end
        return results or {}, err
      end

      -- The finder has a second nil path, and it is the one that actually
      -- fires: `if not prompt or prompt == '' then return nil end`, hit the
      -- instant the picker opens with an empty prompt. Wrapping search()
      -- cannot reach it, so wrap the extension too and guarantee the finder
      -- it builds never hands telescope a nil. new_dynamic is swapped only
      -- for the synchronous call that constructs the picker, then restored.
      local tok, telescope = pcall(require, "telescope")
      if not tok then
        return
      end
      local eok, ext = pcall(function()
        return telescope.extensions.loogle
      end)
      if not eok or type(ext) ~= "table" or type(ext.loogle) ~= "function" then
        return
      end
      local picker = ext.loogle
      ext.loogle = function(opts)
        local finders = require("telescope.finders")
        local new_dynamic = finders.new_dynamic
        finders.new_dynamic = function(o)
          local fn = o.fn
          o.fn = function(prompt)
            return fn(prompt) or {}
          end
          return new_dynamic(o)
        end
        local called, err = pcall(picker, opts)
        finders.new_dynamic = new_dynamic
        if not called then
          error(err)
        end
      end
    end,
  },
}
