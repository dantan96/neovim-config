# Working on this Neovim config

Read this before running anything. The commands below are the ones that work;
the ones under "Do not use" **fail silently and report success**, which is worse
than failing.

## Test

```sh
make test                      # whole suite: 21 files, ~227 cases, mini.test
make test_file FILE=tests/test_profile_theme.lua   # one file
```

`make test` exit code is truthful — 0 means pass. Confirm the tail says
`Fails (0) and Notes (0)`. The runner is mini.test via
`scripts/minimal_init.lua` (config rtp + mini.nvim only; no lazy, no plugins).

Test children load the **full** config via `tests/helpers.lua` → `H.setup_child`,
which also scrubs `$GHOSTTY_NVIM_THEME` and sets `noswapfile shortmess+=A`.
If you write a new test, start from `H.setup_child(child)` rather than calling
`child.restart()` yourself — both of those guards exist because of real flakes.

## Do not use — these lie

| Pattern | What actually happens |
|---|---|
| `nvim --headless -c 'lua <expr>' -c 'qa'` | **Exits 0 even on a hard Lua error.** Never use it to check whether something works. |
| `PlenaryBustedDirectory` / `*_spec.lua` | Plenary globs `*_spec.lua`. Every test here is `test_*.lua`, so it **runs nothing and passes**. |
| `nvim -l script.lua` | Loads **no** user config unless you pass `-u init.lua`. `--cmd "set rtp^=..."` does *not* fix it. `print()` goes to **stderr** under `-l`. |

If you need a non-zero exit from a headless one-liner, end with
`vim.cmd("cquit 1")` — not `error()`.

## Verify a change empirically (required for highlight / LSP / treesitter work)

Static reading cannot confirm highlighting or LSP behaviour here — it depends on
query resolution order, extmark priorities and semantic-token timing. The test
suite does not cover rendering.

```sh
scripts/probe.sh <file> [line] [col]        # JSON: captures, inspect_pos, LSP, diagnostics
scripts/probe.sh ~/Projects/FSharp/NinetyNine/src/Lib.fs 12 5
```

For visual/rendering checks, use mini.test's `child.get_screenshot()` — it
returns aligned ASCII text + highlight-attribute grids that are directly
readable, and mismatches against a reference exit non-zero. Prefer it to taking
an actual screenshot.

Live inspection of an already-running instance:

```sh
nvim --listen /tmp/nvim.sock           # in one terminal
nvim --server /tmp/nvim.sock --remote-expr 'luaeval("vim.json.encode(vim.diagnostic.get(nil))")'
```

State in the commit message what was verified and how.

## Environment gotcha

Claude Code's Bash `PATH` is overridden in `~/.claude/settings.json` and omits
`~/.dotnet/tools` (fantomas, fsautocomplete), `/usr/local/share/dotnet`, and
`~/.cargo/bin` (tree-sitter CLI). **A binary missing from Claude's Bash may be
present for the user's Neovim**, which inherits the login-shell PATH. Before
concluding something isn't installed:

```sh
zsh -lic 'command -v fantomas'
```

## Conventions

- Commit after every change, especially destructive ones — the user wants
  granular revert points.
- Prefer an installed plugin or stock option over bespoke Lua. A ~370-line
  custom formatexpr was rejected in favour of `prettier --prose-wrap always`.
  Check conform/mason and stock options before writing machinery.
- New buffers must open in **normal** mode, never insert (snacks.nvim's
  dashboard uses a terminal buffer, which leaks insert mode into later buffers;
  the fix needs `BufEnter` + `vim.schedule` + `stopinsert`, because a
  synchronous `vim.fn.mode()` check fires too early).
