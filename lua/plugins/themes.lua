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
          -- The fall-through pins below must not hold hand-copied hexes.
          -- They did, briefly, and four of the seven were already stale
          -- against the palette they were copied from — a duplicate value
          -- with a comment naming its source is exactly the B8 shape: wrong
          -- at runtime, invisible on review, and passing every test that
          -- asserts on the effective colour. Read them from the one table
          -- that owns them instead. `defaults()` and not `M.opts`: this runs
          -- before setup({ load_saved = true }) further down, so the user's
          -- saved inputs are not loaded yet and `M.opts` would be the
          -- defaults anyway — said explicitly so it is not mistaken for a
          -- live binding.
          local HUES = require("config.lean.highlights").defaults().hues
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

            -- THE CHANGE — NOW EXPRESSED, in lua/config/lean/highlights.lua.
            -- Read the history below for why it could not live here.
            --
            -- RESOLVED: the world × level grid is synthesised client-side from
            -- an LspTokenUpdate callback into `@lean.<world>.<level>` groups
            -- at priority 128, above Neovim's own type/mod/typemod marks. The
            -- palette, every channel assignment and every deliberate omission
            -- are documented at the top of that file. `require("config.lean.
            -- highlights").setup()` is called at the bottom of this one.
            --
            -- What that means for the groups in THIS file: they still decide
            -- the appearance of anything the grid does not reach — keywords,
            -- tactics, `sorry`, and any token the server sends without a
            -- world or a level. The grid overrides the rest.
            --
            -- ── the history, kept because the dead end is the expensive part
            -- Prop-ness used to arrive as three token TYPES
            -- (leanProof / leanHypothesis / leanProp) and three groups were
            -- defined for them here. The server stopped sending those types
            -- when the declaration kind moved into the token type and
            -- everything else became modifiers, so all three groups had been
            -- dead for some time — they matched nothing, while looking exactly
            -- like working entries in `:highlight`. They are removed rather
            -- than left as decoration; tests/test_lean.lua now fails on any
            -- group naming a token the server does not emit.
            --
            -- Prop-ness is now a MODIFIER PAIR, not a type: a proof is
            -- `propWorld` + `element`, a proposition is `propWorld` + `sort`,
            -- and a predicate such as `Even` is `propWorld` + `former`.
            -- Neovim's group syntax reaches one modifier at a time
            -- (`@lsp.mod.<m>.lean`, `@lsp.typemod.<type>.<m>.lean`) and cannot
            -- require two, so there is no drop-in replacement:
            --   * `@lsp.mod.propWorld.lean` colours the whole Prop column —
            --     proofs, propositions and predicates alike;
            --   * `@lsp.typemod.theorem.propWorld.lean` reaches cited lemmas
            --     but not hypotheses, which are `variable`;
            --   * telling a proposition from a proof of it needs a
            --     LspTokenUpdate handler that inspects both modifiers.
            -- Pick one deliberately rather than restoring a name that no
            -- longer exists.

            -- Everything below is PARKED ON ITS CURRENT APPEARANCE. The server
            -- distinguishes all of it; these links only decide how much of the
            -- distinction is drawn. Each is a one-line edit.
            --
            -- Types. Locals (`{G : Type*}`) come through as typeParameter and
            -- globals as type/inductive/struct/class, so a type variable can be
            -- told from a concrete type. Both looked like `variable` before.
            ["@lsp.type.type.lean"] = { link = "Identifier" },
            ["@lsp.type.typeParameter.lean"] = { link = "Identifier" },
            -- These are the FALL-THROUGH layer: a token that arrives without
            -- both a world and a level never reaches the `@lean.*` grid, so
            -- whatever is pinned here is what it renders as.
            --
            -- They used to be uniformly `Function` (blue), which was right
            -- when the grid had three hues. With the grid widened to twelve
            -- (highlights.lua), a uniform blue fall-through would read as a
            -- DIFFERENT palette — a classification miss would look like a
            -- deliberate colour rather than an absence. So each one now takes
            -- the colour its own kind takes in the grid, and a miss degrades
            -- to a near neighbour instead of to an unrelated hue.
            ["@lsp.type.class.lean"] = { fg = HUES.kind_class, bold = true },
            ["@lsp.type.struct.lean"] = { fg = HUES.data_sort },
            ["@lsp.type.enumMember.lean"] = { fg = HUES.kind_constructor },
            -- A plain `def` is most often data-valued, so the datum colour
            -- rather than the blue it used to inherit from `Function`.
            ["@lsp.type.function.lean"] = { fg = HUES.data_element },
            -- `property`, `enum` and `theorem` are pinned further down, in
            -- the block that keeps catppuccin from owning standard names.
            -- They are recoloured there, not here — a second entry with the
            -- same key is silently last-wins in a Lua table literal, which
            -- is invisible at runtime and passes any test that asserts on
            -- the effective colour.
            -- NOTE the three below lost their `lean` prefix when the server
            -- renamed its token types; the old spellings had silently stopped
            -- matching. `leanSorryLike` above keeps its prefix, being upstream's
            -- own name rather than one this branch invented.
            ["@lsp.type.recursor.lean"] = { link = "Function" },
            -- An `axiom` is the one thing a proof can rest on without proof,
            -- so this is the group most worth un-parking.
            ["@lsp.type.axiom.lean"] = { link = "Function" },
            -- TACTICS OFF THE KEYWORD PURPLE. Dan: "SO MUCH FUCKING PURPLE
            -- ... Yes, split the keyword purple too." Every keyword was
            -- mauve and this group linked straight to it, so `rw`, `simp`,
            -- `exact`, `ring` — the verbs of a proof, and by count the
            -- single biggest contributor to the purple — were mauve too.
            --
            -- Blue, bold: the rebuild moved proofs off `#89b4fa` onto deep
            -- pink, so nothing in the widened palette claims blue any more,
            -- and it is a colour already in use elsewhere in this config.
            -- Declaration keywords (`theorem`, `def`) stay mauve; they are
            -- the skeleton and should stay quiet.
            --
            -- ONLY THIS GROUP. Restyling `@lsp.type.keyword.lean` would take
            -- the tactics with it — 19 keyword atoms include `rw`, `exact`,
            -- `apply` and `ring` — and it is separately addressable only
            -- because the server emits `tactic` for tactic head atoms at
            -- priority 6, above the keyword token covering the same atom.
            -- `import`, `open`, `namespace`, `end` and `section` also arrive
            -- as `keyword` and CANNOT be split here; they belong to the
            -- syntax/treesitter layer.
            ["@lsp.type.tactic.lean"] = { fg = "#89b4fa", bold = true },

            -- ── THE MECHANISM THAT MAKES THIS LIST LOAD-BEARING ─────────
            -- Every time the server starts emitting a STANDARD LSP token
            -- name, catppuccin silently takes that colour over, and the
            -- change looks like a deliberate design decision that nobody
            -- made. This is how it happens:
            --
            --   1. catppuccin's semantic_tokens integration defines the
            --      language-agnostic `@lsp.type.<t>` groups — `enum` is
            --      yellow, `property` is lavender, `struct` is yellow,
            --      `enumMember` is teal, `function` is blue.
            --   2. Neovim's `@`-group fallback is textual and strips
            --      segments from the RIGHT (M3). An undefined
            --      `@lsp.type.enum.lean` therefore resolves to
            --      `@lsp.type.enum` — catppuccin's — not to nothing.
            --   3. A semantic-token extmark outranks the syntax layer
            --      (priority 125 vs 100), so the moment such a token exists
            --      the `leanConstant` blue below is overwritten.
            --
            -- MEASURED on this machine before the fix, by reading rendered
            -- screen cells (`nvim__inspect_cell`) in a real TUI with the
            -- patched server on MIL/C05_.../S03_Infinitely_Many_Primes.lean:
            --
            --   leanConstant                          #89b4fa blue (syntax)
            --   @lsp.type.enum.lean                   #f9e2af yellow   ← ①
            --   @lsp.type.property.lean               #b4befe lavender ← ①
            --   @lsp.typemod.function.defaultLibrary  #fab387 peach    ← ①
            --   @lsp.type.keyword.lean                #cba6f7 mauve    ← ②
            --   @lsp.type.theorem.lean                nil              ← ③
            --   @lsp.type.opaque.lean                 nil              ← ③
            --
            -- ① REGRESSED. `{n : Nat}` rendered yellow and every imported
            --   `def` — `Nat.factorial`, `Nat.Prime` — rendered peach,
            --   because the patched server sets the standard `defaultLibrary`
            --   modifier and catppuccin defines
            --   `@lsp.typemod.function.defaultLibrary`. A typemod mark sits
            --   at priority 127, ABOVE the type mark at 125, so it beats
            --   `@lsp.type.function.lean` as well as the syntax layer. That
            --   is why the typemod line below is needed even though
            --   `function` is already pinned.
            -- ② Not wrong — mauve is what DECLARATION keywords should be —
            --   but it was arriving by inheritance. Pinned, so it cannot go
            --   colourless. `@lsp.type.tactic.lean` used to link to it and
            --   no longer does; see the split above.
            -- ③ Custom names no theme will ever define, so the extmark
            --   contributes nothing and the syntax layer shows through:
            --   still blue, by accident. Pinned because the accident is not
            --   worth relying on and a pinned group can be tested.
            --
            -- NOT a regression, though it looks like one: `ℕ` is a
            -- `keyword` token, not `enum`. The server tokenises the notation
            -- atom, not the constant it abbreviates. Checked before claiming.
            --
            -- `struct`, `enumMember`, `class` and `function` are in exactly
            -- the same position and were already defended above. THE RULE:
            -- any standard LSP token name — TYPE OR MODIFIER — that the
            -- server learns to emit must be given an explicit `.lean` group
            -- here in the same commit, or catppuccin decides its colour.
            -- catppuccin defines 25 language-agnostic `@lsp.*` groups;
            -- tests/test_lean.lua enumerates them and requires every one
            -- whose name Lean's legend can produce to be either pinned here
            -- or exempted by name with a reason.
            -- These three take their widened-grid colour, for the
            -- fall-through reason given above the `class`/`struct` block.
            ["@lsp.type.enum.lean"] = { fg = HUES.data_sort }, -- inductives: Nat, List, True
            ["@lsp.type.property.lean"] = { fg = HUES.kind_projection }, -- structure projections
            ["@lsp.type.theorem.lean"] = { fg = HUES.prop_element }, -- a cited lemma
            ["@lsp.type.opaque.lean"] = { link = "Function" }, -- ditto
            ["@lsp.typemod.function.defaultLibrary.lean"] = { link = "Function" }, -- imported defs
            -- Declaration and term keywords, mauve. NOT to be restyled: 19
            -- keyword atoms include `rw`, `exact`, `apply` and `ring`, so a
            -- change here reaches every tactic too. Tactics are split off
            -- above, through their own token type.
            ["@lsp.type.keyword.lean"] = { link = "Keyword" },

            -- Modifiers. Only `deprecated` is styled — Mathlib deprecates
            -- aggressively (825 files) and a struck-through name is
            -- unambiguous. The rest are on the wire and stylable the same way:
            --   @lsp.mod.simp.lean            `@[simp]` — does simp know this?
            --   @lsp.mod.instance.lean        a registered instance
            --   @lsp.mod.instBinder.lean      an `[Inst α]` binder
            --   @lsp.mod.implicit.lean        bound by `{x}` (`⦃x⦄` is
            --                                 strictImplicit)
            --   @lsp.mod.defaultLibrary.lean  imported, vs proved in this file
            --   @lsp.mod.reducible.lean       `@[reducible]` (`irreducible` too)
            --   @lsp.mod.autoImplicit.lean    the elaborator bound it, not you
            -- ...and the two always-present axes, one modifier from each on
            -- every classified token:
            --   world  propWorld | dataWorld | polyWorld
            --   tower  element   | sort      | former
            -- Combinations use @lsp.typemod.<type>.<mod>.lean, which reaches
            -- one modifier only — see the note on Prop-ness above.
            --
            -- These names are NOT checked by tests/test_lean.lua, which can
            -- only see groups that are actually defined; they went stale once
            -- already when the server dropped its `lean` prefix. Read them
            -- against `SemanticTokenModifier.names` before relying on one.
            ["@lsp.mod.deprecated.lean"] = { strikethrough = true },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin")
    -- The Lean world × level palette. AFTER the colorscheme, because it
    -- defines groups with nvim_set_hl and :colorscheme clears them; the
    -- module re-arms itself on ColorScheme for every later reload.
    --
    -- Wired here rather than in after/ftplugin/lean.lua on purpose: the
    -- groups must exist before the first Lean buffer is tokenised, and this
    -- file is the one place in the config that already owns "highlight
    -- definitions that must survive a colorscheme reload" (LineNrWrap,
    -- LspInlayHint, @lsp.type.variable.lean, all above).
    --
    -- `load_saved` is what makes `:LeanPalette` stick across restarts: it
    -- reads the eleven INPUTS the palette is generated from out of
    -- stdpath("data")/lean-palette.json and regenerates. It is opt-in here
    -- rather than automatic inside setup() so that a bare setup() — what
    -- every test calls — stays deterministic. The read is total: a missing,
    -- truncated or hand-mangled file yields the shipped defaults rather than
    -- throwing, because throwing HERE would abort the colorscheme and leave
    -- the editor unthemed.
    require("config.lean.highlights").setup({ load_saved = true })
    -- :LeanPalette — the interactive picker over those inputs.
    require("config.lean.palette_picker").setup()
  end,
}
