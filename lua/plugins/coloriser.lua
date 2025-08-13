return {
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup()
      vim.api.nvim_set_keymap(
        "n",
        "<leader>ct",
        "<cmd>ColorizerToggle<CR>",
        { noremap = true, silent = true, desc = "Toggle Colorizer" }
      )
    end,
  },
}
