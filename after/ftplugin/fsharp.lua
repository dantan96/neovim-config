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

vim.api.nvim_set_hl(0, "@enum.member.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@lsp.type.enumMember.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(0, "@lsp.type.operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(0, "@keyword.modifier.fsharp", { fg = "#f2cdcd", bold = true })
vim.api.nvim_set_hl(0, "@module.builtin.fsharp", { fg = "#f9e2af", underline = false, italic = true })
vim.api.nvim_set_hl(0, "@lsp.type.module.fsharp", { fg = "#f9e2af", underline = false, italic = true })
vim.api.nvim_set_hl(0, "@lsp.type.namespace.fsharp", { fg = "#f9e2af", underline = false, italic = true })
-- Remove underline and faded color for DiagnosticUnnecessary
vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { underline = nil, fg = nil, bg = nil, default = false })
vim.api.nvim_set_hl(0, "@variable.enum_member.fsharp", { fg = "#f5c2e7", underline = true })
-- vim.api.nvim_set_hl(0, "@punctuation.delimiter.fsharp", { priority = 150 })

-- ""
-- in your fsharp ftplugin or init.lua
-- vim.cmd([[
--   syntax match fsharpConsOp "::" containedin=ALL
--   highlight link fsharpConsOp Operator
-- ]])
-- ""
-- "@module"
-- "@lsp.type.namespace.fsharp"
-- vim.opt_local.indentkeys:remove("o")
-- vim.opt_local.indentkeys:remove("O")
-- vim.opt_local.indentkeys:remove("<Return>")

-- vim.schedule(function()
--   if vim.fn.exists("*FSharpIndent") == 0 then
--     -- Let indent scripts run again, then (re)load vim-fsharp's file
--     vim.cmd([[
--       if exists('b:did_indent') | unlet b:did_indent | endif
--       runtime! indent/fsharp.vim
--     ]])
--   end
--   if vim.fn.exists("*FSharpIndent") == 1 then
--     vim.bo.indentexpr = "FSharpIndent()"
--   end
-- end)
--
--
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "fsharp", "fs", "fsx", "fsi" },
  callback = function(args)
    -- Don’t start a second client if one is already active
    for _, client in pairs(vim.lsp.get_clients({ bufnr = args.buf })) do
      if client.name == "fsautocomplete" then
        return
      end
    end

    local fname = vim.api.nvim_buf_get_name(args.buf)
    local util = require("lspconfig.util")
    local root = util.root_pattern("*.sln", "*.fsproj", ".git")(fname)
    if not root then
      root = vim.fs.dirname(fname) -- fallback to the file’s directory
    end

    vim.lsp.start({
      name = "fsautocomplete",
      cmd = { "fsautocomplete" },
      filetypes = { "fsharp", "fs", "fsx", "fsi" },
      root_dir = root,
      init_options = { AutomaticWorkspaceInit = true },
    })
    vim.cmd("runtime! syntax/fsharp.vim")
    -- Clear any previous matches in this buffer (optional)
    vim.fn.clearmatches()

    -- Add a new high-priority match for "::"
    -- Args:       group           pattern  priority
    vim.fn.matchadd("fsharpOperator", "::", 150)
    vim.fn.matchadd("Operator", "::", 200)
  end,
})
