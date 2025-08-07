-- lua/plugins/lsp.lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
    },
    lazy = false,
    opts = {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
      servers = {
        lua_ls = {},
        basedpyright = {},
        texlab = {},
      },
    },
    config = function(_, opts)
      local lspconfig = require("lspconfig")
      for name, server_opts in pairs(opts.servers) do
        server_opts.capabilities = opts.capabilities
        lspconfig[name].setup(server_opts)
      end
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
