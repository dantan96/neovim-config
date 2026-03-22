return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    cmd = { "Telescope" },
    keys = {
      { "<space>fh", desc = "Help tags" },
      { "<space>ff", desc = "Find files" },
      { "<leader>fb", desc = "Buffers" },
      { "<space>en", desc = "Config files" },
      { "<space>ep", desc = "Plugin files" },
      { "<leader>fg", desc = "Multi grep" },
      { "<leader>fG", desc = "Multi grep (nvim config)" },
      { "<leader>?", desc = "Show keymaps" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }
    },
    config = function()
      require("telescope").setup {
        extensions = {
          fzf = {}
        }
      }
      require("telescope").load_extension("fzf")
      local builtin = require('telescope.builtin')
      vim.keymap.set("n", "<space>fh", builtin.help_tags, { desc = "Help tags" })
      vim.keymap.set("n", "<space>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
      vim.keymap.set("n", "<space>en", function()
        require("telescope.builtin").find_files {
          cwd = vim.fn.stdpath("config")
        }
      end, { desc = "Config files" })
      vim.keymap.set("n", "<space>ep", function()
        require("telescope.builtin").find_files {
          cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
        }
      end, { desc = "Plugin files" })
      vim.keymap.set("n", "<leader>?", builtin.keymaps, { desc = "Show keymaps" })
      require("config.telescope.multigrep").setup()
    end
  }
}
