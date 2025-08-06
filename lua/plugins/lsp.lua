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
        on_attach = function(client, bufnr)
          local caps = client.server_capabilities
          if caps.semanticTokensProvider and caps.semanticTokensProvider.full then
            local augroup = vim.api.nvim_create_augroup("FsacSemanticTokens", {})
            vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave" }, {
              group = augroup,
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.semantic_tokens_full()
              end,
            })
          end
        end,
      })
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
