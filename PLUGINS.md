# Plugin notes — redundancy watch-list and stack decisions

Status as of 2026-07-03 (ecosystem research + config review). Kept
deliberately: none of these is urgent, but each is a known consolidation
candidate. Revisit occasionally.

## Kept for now, replaceable later

| Plugin | Status | Replacement path |
| --- | --- | --- |
| telescope.nvim + fzf-native | Healthy (pushed 2026-06). | `snacks.picker` (already installed via snacks.nvim, just not enabled) covers files/grep/buffers with frecency and `Snacks.picker.undo()`. Dropping telescope also drops fzf-native; plenary stays (harpoon needs it). Would need `config/telescope/multigrep.lua` ported. |
| noice.nvim + nui.nvim | Plateaued; README still "experimental"; recent wontfixes. | Neovim 0.12's `vim._extui` (`require('vim._extui').enable({})`) does native cmdline popup/messages — written by luukvbaal (statuscol author). snacks.notifier already covers notifications. Losses to plan for: noice's LSP hover/signature styling, `<S-Enter>` cmdline redirect, `<leader>m*` history views. Worth an experiment on nightly. |
| peek.nvim | Stale since 2024-08; needs Deno. | markview.nvim (very active) has a `splitview` preview mode; keep peek only while browser-accurate preview + synced scroll is a real habit. |
| vim-obsession | tpope-stable, done not dead. | `mini.sessions` (already installed) or persistence.nvim, unless pairing with tmux-resurrect (obsession is its canonical partner). The `.obsession` sentinel autostart logic would need porting. |
| harpoon2 | Semi-maintained, feature-frozen, works. | No better alternative (grapple is staler). Keep. |
| statuscol.nvim | Low activity, feature-complete. | No replacement for the click handlers + custom vnum segment. Keep; monitor. |
| Penlight | Not used by the config itself. | `lazy = true` since 2026-07: loads only if something `require`s a `pl.*` module. Delete the spec entirely if no external script needs it. |

## Removed (2026-07-03)

- **vim-fsharp** — archived upstream 2024-03; treesitter owns
  highlighting, fsautocomplete owns diagnostics, custom FSI replaces its
  commands. Its `comments`/`commentstring`/`formatoptions`/`suffixesadd`
  lines were inlined into `after/ftplugin/fsharp.lua` (Neovim ships no
  fsharp ftplugin).
- **indent-blankline** placeholder spec — snacks.indent owns indent
  guides.

## Load-bearing facts learned the hard way

- **nvim-treesitter was ARCHIVED 2026-04-03.** This config is already on
  the post-rewrite `main` pattern and pins via lazy-lock, so nothing
  breaks — but the parser registry is frozen upstream. Watch for the
  community successor before parsers drift (~1 year horizon).
- **`vim.pack` (0.12's native package manager)**: no event/ft
  lazy-loading yet; consensus mid-2026 is stay on lazy.nvim.
- **Loose `.fs` files never get FSAC semantic tokens** (architectural:
  only `.fsx` scripts get per-file project options). Name scratch files
  `.fsx`. `config.fsharp.lsp` disables semantic tokens for buffers with
  no `*.fsproj`/`*.sln` ancestor to stop 0.12's per-scroll
  semanticTokens/range requests from erroring forever.
- **User query extensions need `;; extends`** — a non-extends file that
  isn't the first found is silently dropped by
  `vim.treesitter.query.get_files()`. `tests/test_queries.lua` enforces
  this now.
- **Keymap stall invariant**: no single-key `<leader>X` global map may
  coexist with a longer `<leader>X…` map in the same mode
  (timeoutlen stall). Enforced by `tests/test_keymap_ownership.lua`.
  This is why DAP uses F-keys (not `<leader>d*`) and grug-far joined the
  existing `<leader>f*` family.

## Added (2026-07-03)

gitsigns.nvim (`]h`/`[h`, `<leader>g*`, `ih`), lazygit via
`Snacks.lazygit()` (`<leader>gg`; brew-installed binary), nvim-dap +
netcoredbg (F5/F9/F10/F11/F12; netcoredbg via Mason), quicker.nvim
(`<leader>q`), grug-far.nvim (`<leader>fr`), mini.clue (500 ms hints;
part of mini.nvim, no new dependency).

Considered and skipped: easy-dotnet.nvim (most active .NET plugin but
Roslyn/C#-first; adopt only for heavy multi-project solution work),
render-markdown.nvim (markview already covers it), flash.nvim
(taste-dependent; `mini.jump2d` is the free trial), which-key
(mini.clue covers it at zero cost), trouble.nvim/todo-comments (partly
covered by snacks + native diagnostics; revisit on demand),
aerial.nvim (vimtex has a TOC; F# modules rarely deep).
