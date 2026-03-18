-- lua/plugins/lsp.lua
-- Per-server configs live in lsp/<name>.lua and are picked up automatically
-- by the native LSP system. Mason-installed servers are enabled by
-- mason-lspconfig's automatic_enable. Only non-Mason servers need explicit
-- vim.lsp.enable() calls here.
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    lazy = false,
    config = function()
      -- Apply blink.cmp capabilities to every LSP server.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Non-Mason servers must be enabled explicitly.
      vim.lsp.enable("remark_ls") -- installed via npm
      vim.lsp.enable("ruff")      -- installed via brew

      -- Disable formatting for servers that aren't the formatting authority.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end
          if
            client.name == "bashls"
            or client.name == "marksman"
            or client.name == "remark_ls"
            or client.name == "basedpyright"
            or client.name == "ruff"
          then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
        end,
      })
    end,
  },
}
