return {
  "catppuccin/nvim",
  name = "catppuccin",
  -- Derived Ghostty profiles (see lua/config/ghostty_profile.lua) bring
  -- their own colorscheme via lua/plugins/profile_theme.lua; catppuccin
  -- stands down there and ONLY there. tests/test_profile_theme.lua pins
  -- the plain-Ghostty baseline against this condition ever inverting.
  enabled = require("config.ghostty_profile").theme() == nil,
  lazy = false,
  priority = 1000, -- load the colorscheme before other start plugins
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      term_colors = true,
      transparent_background = false,
      no_italic = false,
      no_bold = false,
      -- New: semantic highlighting
      integrations = {
        treesitter = true, -- syntax captures
        semantic_tokens = true, -- LSP semantic-highlight captures
        native_lsp = {
          enabled = true,
          underlines = { errors = { "undercurl" } },
        },
        blink_cmp = true, -- blink.cmp integration (`cmp` is the nvim-cmp key)
        gitsigns = true,
      },
      color_overrides = {
        mocha = {
          -- base = "#000000",
          -- mantle = "#000000",
          -- crust = "#000000",
          base = "#151520",
          mantle = "#101019",
          crust = "#0b0b12",
        },
      },
      highlight_overrides = {
        mocha = function(C)
          return {
            TabLineSel = { bg = C.pink },
            -- Gutter numbers on soft-wrap continuation rows (see the vnum
            -- segment in lua/plugins/statuscol.lua): one step dimmer than
            -- LineNr (surface1) so true lines stand out from wrap segments.
            LineNrWrap = { fg = C.surface0 },
            CmpBorder = { fg = C.surface2 },
            Pmenu = { bg = C.none },
            TelescopeBorder = { link = "FloatBorder" },
            -- Lean's language server emits two semantic-token types that
            -- catppuccin leaves undefined, so they rendered unstyled: plain
            -- `variable`, and Lean's own `leanSorryLike` (sorry/admit and
            -- friends). Defined here rather than in the ftplugin so they
            -- survive a colorscheme reload, as with LineNrWrap above.
            ["@lsp.type.variable.lean"] = { link = "Identifier" },
            ["@lsp.type.leanSorryLike.lean"] = { fg = C.base, bg = C.yellow, bold = true },
            -- Inlay hints (enabled for Lean in after/ftplugin/lean.lua; no
            -- other server here has them on). Lean's are auto-bound implicits
            -- — the ` {α}` the elaborator inserted and you did not type — so
            -- they must be legible, but they are ambient annotation and must
            -- never compete with the code they sit beside.
            --
            -- catppuccin's own LspInlayHint is Comment's exact fg (overlay0)
            -- over a tinted background, which makes a hint read as a comment.
            -- One step brighter, on a recessed chip instead: nothing else in
            -- the buffer has a background, so "not source text" is unambiguous
            -- without spending a colour on it.
            LspInlayHint = { fg = C.overlay1, bg = C.mantle, italic = true },
            -- Lemma references (after/syntax/lean.vim), in the same blue as
            -- the declaration site: `theorem add_zero` and the `add_zero`
            -- inside a later `rw [add_zero]` are the same object, so they get
            -- the same colour. leanDeclarationName is lean.nvim's group for
            -- the declaration side and links to Function.
            leanConstant = { link = "Function" },

            -- ── patched toolchain only ──────────────────────────────────
            -- The groups below need the local Lean branch in
            -- ~/ClaudeProjects/leanSetup/lean4-rich-tokens (branch
            -- dan/rich-semantic-tokens), which classifies every identifier by
            -- the type of the term it elaborates to and by what
            -- `ConstantInfo` says it is. A stock leanls emits only `keyword`
            -- and `variable`, so with it these simply never match.
            --
            -- DELIBERATELY CONSERVATIVE. Everything that already had a colour
            -- keeps it; the only visible change is the one that was asked
            -- for. The extra categories are wired up but parked on their
            -- current appearance, so turning one on is a one-line edit.

            -- THE CHANGE. Things of type Prop, in the blue lemma references
            -- already had. The server sends these as two groups so they can be
            -- told apart; they are linked together here because they are the
            -- same idea — a term whose TYPE is a proposition — differing only
            -- in provenance. Unlink to colour a hypothesis differently from a
            -- lemma you are citing.
            ["@lsp.type.leanProof.lean"] = { link = "Function" }, -- theorem refs
            ["@lsp.type.leanHypothesis.lean"] = { link = "Function" }, -- `h : a = b`
            -- A proposition itself (`p` in `(p : Prop)`, `True`, `Even n`) —
            -- the statement rather than a proof of it. Sapphire reads as
            -- adjacent to the proof blue without collapsing into it.
            ["@lsp.type.leanProp.lean"] = { fg = C.sapphire },

            -- Everything below is PARKED ON ITS CURRENT APPEARANCE. The server
            -- distinguishes all of it; these links only decide how much of the
            -- distinction is drawn. Each is a one-line edit.
            --
            -- Types. Locals (`{G : Type*}`) come through as typeParameter and
            -- globals as type/inductive/struct/class, so a type variable can be
            -- told from a concrete type. Both looked like `variable` before.
            ["@lsp.type.type.lean"] = { link = "Identifier" },
            ["@lsp.type.typeParameter.lean"] = { link = "Identifier" },
            -- Other globals were blue (leanConstant), so they stay blue
            -- whatever kind the environment says they are.
            ["@lsp.type.class.lean"] = { link = "Function" },
            ["@lsp.type.struct.lean"] = { link = "Function" },
            ["@lsp.type.leanInductive.lean"] = { link = "Function" },
            ["@lsp.type.enumMember.lean"] = { link = "Function" }, -- constructors
            ["@lsp.type.function.lean"] = { link = "Function" },
            ["@lsp.type.leanRecursor.lean"] = { link = "Function" },
            -- An `axiom` is the one thing a proof can rest on without proof,
            -- so this is the group most worth un-parking.
            ["@lsp.type.leanAxiom.lean"] = { link = "Function" },
            -- Tactic names, separable from term keywords like `fun` and `let`
            -- for the first time. Park as keyword; give it its own colour to
            -- see the tactic skeleton of a proof at a glance.
            ["@lsp.type.leanTactic.lean"] = { link = "@lsp.type.keyword.lean" },

            -- Modifiers. Only `deprecated` is styled — Mathlib deprecates
            -- aggressively (825 files) and a struck-through name is
            -- unambiguous. The rest are on the wire and stylable the same way:
            --   @lsp.mod.leanSimp.lean        `@[simp]` — does simp know this?
            --   @lsp.mod.leanInstance.lean    instance, or an `[Inst α]` binder
            --   @lsp.mod.leanImplicit.lean    bound by `{x}` / `⦃x⦄`
            --   @lsp.mod.defaultLibrary.lean  imported, vs proved in this file
            --   @lsp.mod.leanReducible.lean   `@[reducible]` / `@[irreducible]`
            -- Combinations use @lsp.typemod.<type>.<mod>.lean.
            ["@lsp.mod.deprecated.lean"] = { strikethrough = true },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
