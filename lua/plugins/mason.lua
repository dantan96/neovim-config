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
      -- stylua is a formatter, not an LSP server; mason-lspconfig would
      -- otherwise auto-enable nvim-lspconfig's stylua config
      -- (cmd = { "stylua", "--lsp" }), which crashes: stylua has no --lsp.
      automatic_enable = { exclude = { "stylua" } },
    },
    lazy = false,
  },
}
