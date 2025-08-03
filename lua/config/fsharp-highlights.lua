-- only F# buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = "fsharp",
  callback = function()
    -- recolour LSP semantic token @lsp.type.function
    -- NOTE: no 'priority' key here
    vim.api.nvim_set_hl(0, "@lsp.type.function", { link = "@function.call" })
  end,
})
