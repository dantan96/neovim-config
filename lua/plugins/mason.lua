return {
  {
    "williamboman/mason.nvim",
    config = true, -- calls require("mason").setup()
    lazy = false, -- eager-load so :Mason* commands & API exist headless
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      automatic_installation = false,
      ensure_installed = {}, -- keep empty; we’ll install via bootstrap
    },
    lazy = false,
  },
}
