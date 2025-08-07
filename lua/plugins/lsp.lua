return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Lua, Python and LaTeX servers
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.basedpyright.setup({ capabilities = capabilities })
      lspconfig.texlab.setup({ capabilities = capabilities })

      -- FsAutoComplete for F#
      -- lspconfig.fsautocomplete.setup({
      --   cmd = { "fsautocomplete" },
      --   init_options = { AutomaticWorkspaceInit = true },
      --   filetypes = { "fsharp", "fs", "fsx", "fsi" },
      --   root_dir = function(fname)
      --     -- Use lspconfig.util.root_pattern first, fall back to vim.fs.dirname
      --     return util.root_pattern("*.sln", "*.fsproj", ".git")(fname) or vim.fs.dirname(fname)
      --   end,
      --   capabilities = capabilities,
      -- })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end
        end,
      })
    end,
  },
}
