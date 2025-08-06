-- lua/config/fsharp-highlights.lua
-- Lower semantic‑token priority for F# so that Tree‑sitter highlighting wins.

-- Create an autocmd that runs for F# filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = "fsharp",
  callback = function(args)
    -- Save the current semantic‑token priority so it can be restored later
    -- local old_priority = vim.hl.priorities.semantic_tokens
    local old_priority = 125

    -- Lower the priority below the Tree‑sitter level (100 is the default TS priority)
    -- Values < 100 ensure Tree‑sitter highlights are used when both are present.
    vim.hl.priorities.semantic_tokens = 125

    -- When the buffer is left/unloaded, restore the old priority
    vim.api.nvim_create_autocmd({ "BufUnload", "BufLeave", "BufWinLeave" }, {
      buffer = args.buf,
      once = true,
      callback = function()
        vim.hl.priorities.semantic_tokens = old_priority
      end,
    })
  end,
})
