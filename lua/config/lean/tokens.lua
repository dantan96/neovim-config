-- lua/config/lean/tokens.lua — repaint a few of leanls's semantic tokens.
--
-- after/syntax/lean.vim splits the propositional vocabulary out of lean.nvim's
-- syntax groups, but syntax loses: the language server marks the same words as
-- semantic tokens, and a semantic extmark sits above syntax highlighting. So
-- `theorem` arrived the same colour as `def` regardless of the syntax file.
--
-- The first fix tried was clearing @lsp.type.keyword.lean so the extmark
-- contributed nothing and syntax showed through. That is the documented opt-out
-- (:h lsp-semantic-highlight) and it worked — but it is far too broad. Asked
-- which atoms leanls actually tags `keyword` on MIL/C02_Basics/S02, it answers
-- with 19 distinct ones:
--
--   #check Type* apply by end exact example have import namespace norm_num
--   rfl ring rw section symm theorem variable ℝ
--
-- Tactics. lean.nvim's syntax file lists no tactic names at all, so clearing
-- the group would have rendered `rw`, `exact`, `apply`, `ring` and friends —
-- most of the text in a proof — as unstyled plain text.
--
-- LspTokenUpdate is the narrow instrument: inspect each token as it arrives and
-- repaint only the handful that are propositional, leaving every other keyword
-- with its normal colour. highlight_token defaults to a priority above the
-- highlighter's own mark, so ours wins without touching anything else.

local M = {}

-- Only consulted for tokens of type `keyword`; the server tags nothing else
-- with these spellings. Connectives are listed because Lean tags notation
-- atoms as keywords too (`ℝ` above is one), and are harmless if it does not:
-- after/syntax/lean.vim already gives them the same group.
local KEYWORD_GROUPS = {
  theorem = "leanPropDeclaration",
  lemma = "leanPropDeclaration",
  axiom = "leanPropDeclaration",
  example = "leanPropDeclaration",
  Prop = "leanProp",
}
for _, connective in ipairs({ "∀", "∃", "¬", "∧", "∨", "↔", "→", "≠", "≤", "≥", "∈", "∉", "⊆", "⊂", "∅" }) do
  KEYWORD_GROUPS[connective] = "leanLogicOp"
end

---Highlight group to repaint a token with, or nil to leave it alone.
---@param token_type string LSP semantic token type
---@param text string source text the token covers
---@return string|nil
function M.hl_for(token_type, text)
  if token_type ~= "keyword" then
    return nil
  end
  return KEYWORD_GROUPS[text]
end

vim.api.nvim_create_autocmd("LspTokenUpdate", {
  group = vim.api.nvim_create_augroup("LeanSemanticTokens", { clear = true }),
  desc = "Colour Lean's propositional keywords apart from its tactics",
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "lean" then
      return
    end
    local token = args.data.token
    -- Multi-line tokens do not occur here, and nvim_buf_get_text would need
    -- different arguments if they did; bail rather than guess.
    local ok, text = pcall(
      vim.api.nvim_buf_get_text,
      args.buf,
      token.line,
      token.start_col,
      token.line,
      token.end_col,
      {}
    )
    if not ok or not text[1] then
      return
    end
    local group = M.hl_for(token.type, text[1])
    if group then
      vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, group)
    end
  end,
})

return M
