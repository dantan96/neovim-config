return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ha", desc = "Harpoon add" },
    { "<leader>hh", desc = "Harpoon menu" },
    { "<leader>1", desc = "Harpoon 1" },
    { "<leader>2", desc = "Harpoon 2" },
    { "<leader>3", desc = "Harpoon 3" },
    { "<leader>4", desc = "Harpoon 4" },
    { "<leader>5", desc = "Harpoon 5" },
  },
  config = function()
    local harpoon = require("harpoon")
    harpoon:setup()

    vim.keymap.set("n", "<leader>ha", function()
      harpoon:list():add()
    end, { desc = "Harpoon add" })
    vim.keymap.set("n", "<leader>hh", function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon menu" })

    for i = 1, 5 do
      vim.keymap.set("n", "<leader>" .. i, function()
        harpoon:list():select(i)
      end, { desc = "Harpoon to file " .. i })
    end
  end,
}
