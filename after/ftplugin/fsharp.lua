-- Use spaces for indentation in F# (required by lightweight syntax)
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4

-- Optional: make tabs visible while editing
-- vim.opt_local.list = true
-- vim.opt_local.listchars:append({ tab = "» " })

vim.opt_local.autoindent = false
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

-- vim.opt_local.indentkeys:remove("o")
-- vim.opt_local.indentkeys:remove("O")
-- vim.opt_local.indentkeys:remove("<Return>")

vim.schedule(function()
  if vim.fn.exists("*FSharpIndent") == 0 then
    -- Let indent scripts run again, then (re)load vim-fsharp's file
    vim.cmd([[
      if exists('b:did_indent') | unlet b:did_indent | endif
      runtime! indent/fsharp.vim
    ]])
  end
  if vim.fn.exists("*FSharpIndent") == 1 then
    vim.bo.indentexpr = "FSharpIndent()"
  end
end)
