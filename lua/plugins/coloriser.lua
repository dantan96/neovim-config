return {
  {
    "catgoose/nvim-colorizer.lua",
    event = "VeryLazy",
    config = function()
      require("colorizer").setup({ filetypes = { "css", "html", "lua" } })
      vim.keymap.set("n", "<leader>ct", "<cmd>ColorizerToggle<CR>", { desc = "Toggle Colorizer" })
    end,
  },
}
