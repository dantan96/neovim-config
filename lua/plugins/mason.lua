return {
  {
    "mason-org/mason.nvim",
    config = true, -- calls require("mason").setup()
    lazy = false, -- eager-load so :Mason* commands & API exist headless
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      automatic_installation = false,
      ensure_installed = {}, -- keep empty; we’ll install via bootstrap
      -- stylua is a formatter, not an LSP server; its lsp/stylua.lua config
      -- (cmd = { "stylua", "--lsp" }) crashes because stylua has no --lsp flag.
      automatic_enable = { exclude = { "stylua" } },
    },
    lazy = false,
  },
}
