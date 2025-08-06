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
      local util = require("lspconfig.util")
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.basedpyright.setup({ capabilities = capabilities })
      lspconfig.texlab.setup({ capabilities = capabilities })
      lspconfig.fsautocomplete.setup({
        cmd = { "fsautocomplete" },
        init_options = { AutomaticWorkspaceInit = true },
        root_dir = function(fname)
          return util.root_pattern("*.sln", "*.fsproj", ".git")(fname) or vim.fs.dirname(fname)
        end,
        capabilities = capabilities,
      })
      -- filetypes = { "fsharp", "fs", "fsx", "fsi" },
      -- settings = {
      --   FSharp = {
      --     EnableReferenceCodeLens = false,
      --   },
      -- },
      -- on_attach = function(client, bufnr)
      --   -- client.server_capabilities.semanticTokensProvider = nil
      --   client.server_capabilities.codeLensProvider = nil
      --   client.server_capabilities.inlayHintProvider = nil
      -- end,
      -- handlers = {
      --   ["textDocument/codeLens"] = function() end,
      --   ["textDocument/inlayHint"] = function() end,
      -- },
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
