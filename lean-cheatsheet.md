# Lean 4 Cheat Sheet

Open with `\?` in any Lean buffer. `q` closes. Local leader is `\`.

Everything below was verified against a real mathlib project, except the two
rows marked *unverified*.

## Infoview & goals

| Keys | Action |
|------|--------|
| `\i` | Toggle the infoview |
| `\<Tab>` | Jump into the infoview window |
| `\p` | Pause / unpause pin updates |
| `\x` | Place a pin at the cursor |
| `\c` | Clear all pins |
| `\v` | Change infoview view options |
| `\w` / `\W` | Enable / disable widgets |
| `\s` | Accept the first "Try this" suggestion |
| `\r` | Restart the Lean server for this file |

### Diff pins

| Keys | Action |
|------|--------|
| `\dx` | Set a diff pin |
| `\dc` | Clear diff pins |
| `\dd` | Toggle auto-diff mode |
| `\dt` | Toggle auto-diff without clearing |

## Inside the infoview window

| Keys | Action |
|------|--------|
| `<CR>` / `K` | Click the interactive element |
| `gK` | Select widget |
| `<Tab>` / `<S-Tab>` | Enter tooltip / back to parent |
| `<Esc>` or `C` | Clear all tooltips |
| `gd` `gD` `gy` | Go to definition / declaration / type |
| `]g` `[g` | Next / previous goal |
| `]h` `[h` | Next / previous hypothesis |
| `]s` `[s` | Next / previous suggestion |
| `]l` `[l` | Next / previous link |
| `]t` `[t` | Next / previous trace |
| `\g` | Jump to the first goal |
| `\/` | Search trace messages |
| `\<Tab>` | Jump back to the Lean file |

## Language server

| Keys | Action |
|------|--------|
| `K` | Interactive hover (lean.nvim overrides the default) |
| `<C-]>` | Go to definition (via `tagfunc`); `<C-t>` to come back |
| `gO` | Document symbols |
| `\n` | Rename |
| `\a` | Code action |
| `\f` | References |
| `[d` `]d` | Previous / next diagnostic |

`\n` `\a` `\f` are defined in this config, not by lean.nvim: mini.operators
owns the `gr` prefix, which shadows Neovim's built-in `grn` / `gra` / `grr`
LSP maps, leaving those actions otherwise unreachable.

## Commands

| Command | Action |
|---------|--------|
| `:LeanGoal` | Goal at the cursor, in a popup |
| `:LeanTermGoal` | Term-mode type information |
| `:LeanLineDiagnostics` | Diagnostics for the current line |
| `:LeanRestartFile` | Restart the server for this file |
| `:LeanRefreshFileDependencies` | Re-read changed imports |
| `:LeanSorryFill` | Fill in `sorry` placeholders |
| `:LeanAbbreviationsReverseLookup` | How do I type the character under the cursor? |
| `:LeanInfoviewToggle` | Toggle the infoview |
| `:LeanInfoviewAddPin` / `…ClearPins` | Manage pins |
| `:LeanGotoInfoview` | Jump into the infoview |
| `:Telescope loogle` | Search mathlib by type signature (*unverified* — hits the network) |

## Unicode abbreviations

Type the sequence in insert mode; it expands on the next non-matching
character (usually space). `\\` on a character tells you how to type it.

| Type | Get | | Type | Get |
|------|-----|-|------|-----|
| `\to` | → | | `\alpha` | α |
| `\l` | ← | | `\beta` | β |
| `\iff` | ↔ | | `\gamma` | γ |
| `\not` | ¬ | | `\lambda` | λ |
| `\and` | ∧ | | `\epsilon` | ε |
| `\or` | ∨ | | `\delta` | δ |
| `\forall` | ∀ | | `\Gamma` | Γ |
| `\ex` | ∃ | | `\Sigma` | Σ |
| `\in` | ∈ | | `\N` | ℕ |
| `\notin` | ∉ | | `\Z` | ℤ |
| `\sub` | ⊆ | | `\Q` | ℚ |
| `\cup` | ∪ | | `\R` | ℝ |
| `\cap` | ∩ | | `\C` | ℂ |
| `\empty` | ∅ | | `\inv` | ⁻¹ |
| `\ne` | ≠ | | `\comp` | ∘ |
| `\le` `\ge` | ≤ ≥ | | `\times` | × |
| `\<>` | ⟨⟩ | | `\sum` | ∑ |
| `\.` | · | | `\prod` | ∏ |
| `\mapsto` | ↦ | | `\1` `\2` | ₁ ₂ |

Greedy matching: `\bN` gives βN, not ℕ, because `\b` → β wins. Use `\N`.

## Toolchain (shell)

| Command | Action |
|---------|--------|
| `lake build` | Build the project |
| `lake exe cache get` | Fetch prebuilt mathlib oleans |
| `lake update` | Update dependencies |
| `elan show` | Active toolchain |
| `elan self update` | Update elan itself |

Graphics widgets need `resvg` for SVG (installed) and a Kitty-protocol
terminal — Ghostty qualifies. *Unverified*: headless testing cannot render
images.
