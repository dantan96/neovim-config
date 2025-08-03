return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
    },
    config = function()
      -- require("mason").setup()
      -- require("mason-lspconfig").setup()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local lspconfig = require("lspconfig")
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.basedpyright.setup({ capabilities = capabilities })
      lspconfig.texlab.setup({ capabilities = capabilities })
      -- lspconfig.fsautocomplete.setup({
      --   capabilities = capabilities,
      --   cmd = { "fsautocomplete", "--adaptive-lsp-server-enabled" },
      --   filetypes = { "fsharp", "fs", "fsx", "fsi" },
      --   on_attach = function(client, bufnr)
      --     client.server_capabilities.semanticTokensProvider = nil
      --   end,
      -- })
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end
          -- if client.supports_method('textDocument/formatting') then
          --   vim.api.nvim_create_autocmd("BufWritePre", {
          --     buffer = args.buf,
          --     callback = function()
          --       vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
          --     end,
          --   })
          -- end
        end,
      })
    end,
  },
}
