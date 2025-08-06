return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
    },
    opts = {
      -- capabilities for completion and other LSP features
      capabilities = require("blink.cmp").get_lsp_capabilities(),

      -- per-server settings
      servers = {
        lua_ls = {},
        basedpyright = {},
        texlab = {},

        fsautocomplete = {
          cmd = { "fsautocomplete" },
          init_options = { AutomaticWorkspaceInit = true },
          root_dir = function(fname)
            local util = require("lspconfig.util")
            -- use vim.fs.dirname as a fallback on Neovim ≥0.10
            return util.root_pattern("*.sln", "*.fsproj", ".git")(fname) or vim.fs.dirname(fname)
          end,
          filetypes = { "fsharp", "fs", "fsx", "fsi" },
        },
      },
    },
    -- config = function()
    --   vim.api.nvim_create_autocmd("LspAttach", {
    --     callback = function(args)
    --       local client = vim.lsp.get_client_by_id(args.data.client_id)
    --       if not client then
    --         return
    --       end
    --     end,
    --   })
    -- end,
  },
}
