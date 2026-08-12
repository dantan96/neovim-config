-- lua/config/lean/namespace_hl.lua — the two things the semantic palette
-- cannot reach: namespace/module PATHS, and the keywords the server lumps
-- into one undifferentiated `keyword` token.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS IS A CAPTURE GAP AND NOT A PALETTE GAP — measured, not assumed
-- ─────────────────────────────────────────────────────────────────────────
-- `docs/lean-highlighting/tools/lsp_probe.py` against the patched server, on
-- MIL/C05.../S02_Induction_and_Recursion.lean (544 tokens) and on
-- HighlightGallery.lean:
--
--   import Mathlib.Data.Nat.GCD.Basic  ->  ONE token: keyword 'import'
--   namespace MyNat                    ->  ONE token: keyword 'namespace'
--   end MyNat                          ->  ONE token: keyword 'end'
--   open Function Set Order            ->  ONE token: keyword 'open'
--   universe u v                       ->  ONE token: keyword 'universe'
--
-- The path itself is not a token at ANY position, so no `@lsp.*` group — no
-- amount of palette work — can ever colour it. Nothing above priority 50
-- claims those columns either, which is why `after/syntax/lean.vim` is the
-- right layer for the path and this file only supplies the groups it links to.
--
-- The keywords are the opposite case: they DO carry a token, of type
-- `keyword`, so the syntax layer at 50 loses to it and only a token-level
-- handler can split them.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY SPLITTING A DOTTED IDENTIFIER IS SAFE — by construction, not by luck
-- ─────────────────────────────────────────────────────────────────────────
-- A resolved global reference arrives as ONE token spanning the whole dotted
-- name (`'Nat.succ_ne_zero'`, `'Nat.succ.inj'`, `'Finset.sum'`), so the
-- `Nat.` prefix is not separately addressable and has to be split here.
--
-- The obvious fear is that dot-notation on a LOCAL would be caught by the
-- same rule and painted as namespace scaffolding — `n.succ` is the commonest
-- idiom in Lean. It cannot happen, and the probe proves it rather than
-- suggesting it. In `example (n : Nat) : n.succ ≠ Nat.zero` the server emits
--
--   4:20  variable   +local  'n'          <- two tokens, the dot untokenized
--   4:22  enumMember         'succ'
--   4:29  enumMember         'Nat.zero'   <- one token, fully qualified
--
-- Dot-notation on a term is ALREADY split server-side. Therefore a token
-- whose text contains a `.` is always a fully-qualified constant, and every
-- component before the last `.` is genuinely a namespace. There is no
-- heuristic here.
--
-- ─────────────────────────────────────────────────────────────────────────
-- PRIORITY 129, AND THE CONTRACT WITH highlights.lua
-- ─────────────────────────────────────────────────────────────────────────
-- Neovim lays three marks per token at 125/126/127; `highlights.lua`
-- synthesises the `@lean.<world>.<level>` grid at 128. This file paints at
-- **129** and highlights.lua has agreed to stay at 128. That split is the
-- whole layering:
--
--   * a KEYWORD mark here replaces the whole token's colour, and is only ever
--     applied to a fixed, named list of keyword texts (below). Every other
--     keyword — `theorem`, `def`, `Type*`, `ℕ`, `_`, and on the patched
--     server every tactic, which arrives as type `tactic` and not `keyword`
--     at all — is left entirely to highlights.lua and the theme.
--   * a PREFIX mark inside a dotted reference sets NO foreground. It carries
--     only `underdotted` + `sp`, so Neovim's per-attribute composition leaves
--     highlights.lua's foreground in place and the final component of the
--     name stays the dominant thing. Nothing this file does can change a
--     colour highlights.lua chose.
--
-- `@lsp.type.keyword.lean` is never touched. Dispatch is on the token's TEXT,
-- which is also why this file is correct against the stock toolchain, where
-- `rw`/`exact`/`apply` DO arrive as `keyword`: they are simply not in the
-- list.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS FILE AND NOT after/ftplugin/lean.lua
-- ─────────────────────────────────────────────────────────────────────────
-- Same reason as document_highlight.lua: the feature is autocmds, and
-- tests/test_invariants.lua asserts that re-sourcing an ftplugin leaves the
-- autocmd population unchanged. Required once from the lean.nvim spec's
-- `init`, it runs exactly once.
--
-- The ColorScheme autocmd is not optional either: `:colorscheme` clears every
-- group, and a `hi def link` in a syntax file does not reliably survive it.

local M = {}

-- ── the palette ────────────────────────────────────────────────────────
-- Hand-picked, every one of them. Nothing here is computed from anything
-- else, and nothing is blended toward a background to make it recede — a
-- namespace prefix is scaffolding, but scaffolding you can see.
--
-- Claimed against `wt/palette` (main confirmed brass, flamingo, olive and
-- vetoed catppuccin overlay0 for the separators in favour of SlateGray,
-- which is Dan's own punctuation colour in spthy-colorscheme.lua).
M.palette = {
  -- Addressing machinery: the module keywords AND the namespace components
  -- that qualify a name. Deliberately ONE colour for both, so `import` and
  -- `Mathlib.Order.Filter` read as a single gesture rather than two rules.
  brass = "#e5b567",
  -- The name you actually mean: the last component of a module path.
  flamingo = "#f2cdcd",
  -- Separators only. spthy-colorscheme.lua `slateGrayPlain`, which does this
  -- same job there for brackets, colons and commas.
  slate = "#708090",
  -- Term and binder keywords, moved off mauve.
  olive = "#b8bb26",
}

-- ── keyword classification ─────────────────────────────────────────────
-- One table, editable in one place. The key is the token's exact text.
--
-- DELIBERATELY ABSENT, and each for a reason:
--   * `theorem def instance structure class inductive abbrev` — declaration
--     keywords keep mauve. They are the skeleton of the file and should stay
--     quiet; a `theorem` keyword and a lemma name are never confused.
--   * `Type* Sort ℕ` — notation atoms the server also calls `keyword`
--     (GOTCHAS B7). They are types, not structure; highlights.lua's business.
--   * `by` — reads as the head of the tactic block, and tactics are blue on
--     `wt/palette`. Left alone rather than claimed from here.
--   * `simp` — arrives as `keyword` when it is the ATTRIBUTE in `@[simp]`.
--     Colouring it as a binder would be plainly wrong.
--   * `_` — a hole, not a keyword in any useful sense.
--
-- `∀ ∃ λ` are NOT here because the server emits no token for them at all
-- (verified: `∀ s, sᶜ ∈ f` in HighlightGallery.lean yields tokens for `s`
-- and `f` and nothing for `∀`). They are reached from after/syntax/lean.vim,
-- which is unopposed at those columns.
M.KEYWORDS = {
  -- module / file structure -> brass
  ["import"] = "@lean.path.keyword",
  ["open"] = "@lean.path.keyword",
  ["export"] = "@lean.path.keyword",
  ["namespace"] = "@lean.path.keyword",
  ["end"] = "@lean.path.keyword",
  ["section"] = "@lean.path.keyword",
  ["variable"] = "@lean.path.keyword",
  ["universe"] = "@lean.path.keyword",
  -- term / binder -> olive
  ["fun"] = "@lean.binder.keyword",
  ["let"] = "@lean.binder.keyword",
  ["have"] = "@lean.binder.keyword",
  ["show"] = "@lean.binder.keyword",
  ["suffices"] = "@lean.binder.keyword",
  ["match"] = "@lean.binder.keyword",
  ["with"] = "@lean.binder.keyword",
  ["do"] = "@lean.binder.keyword",
  ["from"] = "@lean.binder.keyword",
}

-- ── the groups ─────────────────────────────────────────────────────────
-- Every entry is a COMPLETE spec. GOTCHAS B1: a partial child definition
-- kills inheritance entirely, so nothing here relies on `@lean.path`
-- resolving to anything.
--
-- The one deliberate exception is `@lean.ns.prefix`, which sets no `fg` ON
-- PURPOSE — see the header. It is not a partial child of anything; `@lean.ns`
-- is never defined, so there is no inheritance to break.
--
-- Written as a function rather than a literal so lua_ls sees one table
-- constructor and reports `duplicate-index` if a name is ever repeated
-- (GOTCHAS B8: a duplicate key is silently last-wins and every test asserting
-- on the effective colour passes).
---@return table<string, vim.api.keyset.highlight>
function M.groups()
  local p = M.palette
  return {
    -- On a command line. Nothing else claims these columns.
    ["@lean.path.keyword"] = { fg = p.brass, bold = true },
    ["@lean.path.prefix"] = { fg = p.brass, underdotted = true, sp = p.brass },
    ["@lean.path.dot"] = { fg = p.slate },
    ["@lean.path.final"] = { fg = p.flamingo, bold = true },
    ["@lean.binder.keyword"] = { fg = p.olive, bold = true },
    -- Inside a dotted reference, over highlights.lua's 128. No fg: the
    -- foreground underneath is the whole point of leaving it alone.
    ["@lean.ns.prefix"] = { underdotted = true, sp = p.brass },
    ["@lean.ns.dot"] = { fg = p.slate },
  }
end

--- Priority of every mark this module sets.
---
--- 129 = `vim.hl.priorities.semantic_tokens + 4`. Neovim's own three marks are
--- at +0/+1/+2 and highlights.lua synthesises at +3. Computed from the live
--- table rather than hardcoded so that a user lowering `semantic_tokens` (as
--- lua/config/fsharp/semantic_priority.lua does for F#) moves this with it
--- instead of stranding it above.
function M.priority()
  return vim.hl.priorities.semantic_tokens + 4
end

-- ── splitting a dotted name ────────────────────────────────────────────

--- Byte ranges of the namespace components and separators of a dotted name.
---
--- Returns ranges RELATIVE to the start of `text`, half-open, as
--- `{ from, to, kind }` with `kind` one of `"prefix"` / `"dot"`. The final
--- component is deliberately absent: it keeps whatever colour it already had.
---
--- Byte offsets are correct without any UTF-16 arithmetic. `.` is 0x2E and no
--- byte of a multi-byte UTF-8 sequence is ever below 0x80, so a plain byte
--- scan cannot land inside `α` or a subscript; and `token.start_col` is
--- already a byte index (semantic_tokens.lua converts with `str_byteindex`).
---
---@param text string the token's source text
---@return { [1]: integer, [2]: integer, [3]: string }[]
function M.split(text)
  local out = {}
  -- A guillemet-quoted identifier may contain a dot that is part of the NAME
  -- (`«foo.bar»`), so it is not a separator. Cheap and total: refuse to split
  -- anything containing a guillemet at all.
  if text:find("«", 1, true) then
    return out
  end
  local seg = 0 -- 0-based byte offset where the current component starts
  local i = 1
  while true do
    local d = text:find(".", i, true) -- 1-based index of the dot
    if not d then
      break
    end
    -- Skip a zero-length component (`Foo..Bar` is not real Lean, but a
    -- half-typed buffer is the server's normal state).
    if d - 1 > seg then
      out[#out + 1] = { seg, d - 1, "prefix" }
    end
    out[#out + 1] = { d - 1, d, "dot" }
    seg = d
    i = d + 1
  end
  return out
end

-- ── the token handler ──────────────────────────────────────────────────

--- What, if anything, this module wants to paint for one token.
---
--- Pure: takes the token and its source text and returns a list of
--- `{ start_col, end_col, group }` in BUFFER byte columns. Separated from the
--- autocmd so it can be tested without a language server — and so a test can
--- be made non-vacuous by feeding it a token it must refuse.
---
---@param token table `ev.data.token` from |LspTokenUpdate|
---@param text string the buffer text the token covers
---@return { [1]: integer, [2]: integer, [3]: string }[]
function M.marks(token, text)
  local out = {}
  local mods = token.modifiers or {}

  if token.type == "keyword" then
    local group = M.KEYWORDS[text]
    if group then
      out[#out + 1] = { token.start_col, token.end_col, group }
    end
    return out
  end

  -- A local binding is never dotted, and this prunes the largest single
  -- population of tokens (244 of 544 in the S02 probe) before touching text.
  if mods["local"] then
    return out
  end

  -- GOTCHAS B4: one underline style per cell. An `axiom` gets a double
  -- underline and an auto-bound implicit a dashed one from highlights.lua,
  -- both spanning the whole token. Splitting the underline mid-name would
  -- break the stronger signal — `Classical.choice` "rests on nothing" matters
  -- more than "`Classical` is a path segment" — so on those tokens we do not
  -- split at all.
  if mods.axiom or mods.autoImplicit then
    return out
  end

  for _, r in ipairs(M.split(text)) do
    out[#out + 1] = {
      token.start_col + r[1],
      token.start_col + r[2],
      r[3] == "dot" and "@lean.ns.dot" or "@lean.ns.prefix",
    }
  end
  return out
end

--- Syntax-group links that after/syntax/lean.vim also states as `hi def link`.
---
--- Restated here because `:colorscheme` runs `:hi clear`, which drops links as
--- well as definitions, and the syntax file is not re-sourced. Emitted with
--- `default = true`, i.e. exactly `hi def link`, so an explicit
--- `:hi link leanPathFinal Whatever` from the user still wins and survives.
M.LINKS = {
  leanModuleKeyword = "@lean.path.keyword",
  leanBinderKeyword = "@lean.binder.keyword",
  leanPathQual = "@lean.path.keyword",
  leanPathPrefix = "@lean.path.prefix",
  leanPathDot = "@lean.path.dot",
  leanPathFinal = "@lean.path.final",
}

--- Define every group. Idempotent; re-run from the ColorScheme autocmd.
function M.define()
  for name, spec in pairs(M.groups()) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  for name, target in pairs(M.LINKS) do
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
end

local armed = false

function M.setup()
  M.define()
  if armed then
    return M
  end
  armed = true

  local aug = vim.api.nvim_create_augroup("LeanNamespaceHighlight", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    desc = "Lean: re-emit the namespace/keyword groups a colorscheme cleared",
    callback = M.define,
  })

  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = aug,
    desc = "Lean: split dotted names and re-colour module/binder keywords",
    callback = function(ev)
      local token = ev.data.token
      -- Multi-line tokens exist (Neovim 0.12 supports them) but no identifier
      -- or keyword is one, and the arithmetic below assumes a single line.
      if token.line ~= token.end_line then
        return
      end
      local ok, lines =
        pcall(vim.api.nvim_buf_get_text, ev.buf, token.line, token.start_col, token.line, token.end_col, {})
      if not ok or not lines[1] then
        return
      end
      local priority = M.priority()
      for _, m in ipairs(M.marks(token, lines[1])) do
        -- A COPY of the token with the columns moved, so `set_mark` reads
        -- every other field exactly as it would have. `highlight_token` puts
        -- the mark in the semantic-token engine's own namespace, which means
        -- the engine deletes it on the next refresh — the reason not to
        -- manage a namespace here.
        local sub = vim.tbl_extend("force", token, { start_col = m[1], end_col = m[2] })
        vim.lsp.semantic_tokens.highlight_token(sub, ev.buf, ev.data.client_id, m[3], {
          priority = priority,
        })
      end
    end,
  })

  return M
end

return M
