-- lua/plugins/latex.lua
return {
  {
    "lervag/vimtex",
    -- Load only when editing TeX files
    ft   = { "tex", "plaintex" },
    cmd  = { "VimtexInverseSearch" },

    -- Options *must* be set before VimTeX loads
    init = function()
      -- 1 ▸ keep Treesitter and silence VimTeX’s banner
      vim.g.vimtex_syntax_enabled     = 0

      -- 2 ▸ make latexmk run in “preview-continuous” mode
      vim.g.vimtex_compiler_latexmk   = { continuous = 1 }

      vim.g.vimtex_view_method        = "skim" -- use Skim as the viewer
      vim.g.vimtex_view_skim_sync     = 1      -- forward+inverse search
      vim.g.vimtex_view_skim_activate = 1      -- give Skim focus on forward search
      vim.g.vimtex_quickfix_mode      = 0      -- leave quickfix closed unless errors

      -- Auto-start \ll as soon as VimTeX finishes initialisation
      vim.api.nvim_create_autocmd('User', {
        pattern  = 'VimtexEventInitPost',
        callback = function() vim.cmd('VimtexCompile') end,
      })
    end,
  },
}
