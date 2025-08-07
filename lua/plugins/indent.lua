-- lua/plugins/indent.lua
return {
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPre",
    main = "ibl",
    opts = {
      indent = { char = "│" },
      scope = { enabled = true },
      exclude = {
        filetypes = { "help", "alpha", "dashboard", "lazy" },
        buftypes = { "terminal", "nofile" },
      },
    },
  },
}
