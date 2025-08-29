return {
  {
    "norcalli/nvim-colorizer.lua",
    -- cmd = {
    --   "ColorizerAttachToBuffer",
    --   "ColorizerToggle",
    --   "ColorizerDetachFromBuffer",
    --   "ColorizerReloadAllBuffers",
    -- },
    config = function()
      require("colorizer").setup({ "css", "html", "lua" })
      vim.api.nvim_set_keymap(
        "n",
        "<leader>ct",
        "<cmd>ColorizerToggle<CR>",
        { noremap = true, silent = true, desc = "Toggle Colorizer" }
      )
    end,
  },
}
