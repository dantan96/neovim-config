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
        bashls = {
          filetypes = { "sh", "bash", "zsh" },
          settings = {
            bashIde = {
              globPattern = "**/*@(.sh|.bash|.zsh|.env)",
              shellcheckPath = "shellcheck", -- if installed
            },
          },
        },

        -- Marksman: prefer .git / .marksman.toml / marksman.toml; else file dir
        marksman = {
          single_file_support = true,
          root_dir = function(fname)
            local cfgdir = vim.fn.stdpath("config")
            local start = (fname and fname ~= "" and fname)
              or vim.api.nvim_buf_get_name(0)
            if start == "" then
              start = vim.fn.getcwd()
            end
            local hit = vim.fs.find(
              { ".git", ".marksman.toml", "marksman.toml" },
              { path = start, upward = true }
            )[1]
            local root = hit and vim.fs.dirname(hit) or vim.fs.dirname(start)
            -- If we found your nvim config dir but the file isn't actually in it, ignore that root
            if
              not start:find(cfgdir, 1, true) and root:find(cfgdir, 1, true)
            then
              root = vim.fs.dirname(start)
            end
            return root
          end,
        },

        -- remark-language-server: prefer remark config / .git; else file dir
        remark_ls = {
          cmd = { "remark-language-server", "--stdio" },
          filetypes = { "markdown", "markdown.mdx" },
          settings = { remark = { requireConfig = false } },
          single_file_support = true,
          root_dir = function(fname)
            local cfgdir = vim.fn.stdpath("config")
            local start = (fname and fname ~= "" and fname)
              or vim.api.nvim_buf_get_name(0)
            if start == "" then
              start = vim.fn.getcwd()
            end
            local hit = vim.fs.find({
              ".remarkrc.mjs",
              ".remarkrc.js",
              ".remarkrc.cjs",
              ".remarkrc",
              ".remarkrc.json",
              ".remarkrc.yaml",
              ".remarkrc.yml",
              "remark.config.mjs",
              "remark.config.js",
              "remark.config.cjs",
              ".marksman.toml",
              "marksman.toml", -- also works as a root marker
              ".git",
            }, { path = start, upward = true })[1]
            local root = hit and vim.fs.dirname(hit) or vim.fs.dirname(start)
            if
              not start:find(cfgdir, 1, true) and root:find(cfgdir, 1, true)
            then
              root = vim.fs.dirname(start)
            end
            return root
          end,
        },
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
          if
            client.name == "bashls"
            or client.name == "marksman"
            or client.name == "remark_ls"
          then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
        end,
      })
    end,
  },
}
