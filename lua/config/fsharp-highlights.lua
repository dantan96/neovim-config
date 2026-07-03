-- lua/config/fsharp-highlights.lua
-- Lower semantic-token priority for F# so that Tree-sitter highlighting wins.

vim.api.nvim_create_autocmd("FileType", {
  pattern = "fsharp",
  group = vim.api.nvim_create_augroup("fsharp_semantic_priority", {
    clear = true,
  }),
  callback = function()
    -- Set once per session, the first time an F# buffer opens, and never
    -- restore. vim.hl.priorities is global, so a per-buffer save/restore
    -- (the previous approach) was racy: the "restore" fired on the first
    -- window switch, and with two F# buffers open the second captured the
    -- already-lowered value and could restore it permanently. Leaving the
    -- priority at 95 is harmless in practice: it only changes rendering
    -- where semantic tokens and Tree-sitter captures disagree, which is
    -- exactly the F# situation this exists to fix.
    if vim.g._fsharp_semantic_priority_set then
      return
    end
    vim.g._fsharp_semantic_priority_set = true

    -- Below the default Tree-sitter priority (100), so Tree-sitter
    -- highlights win when both are present.
    vim.hl.priorities.semantic_tokens = 95
  end,
})
