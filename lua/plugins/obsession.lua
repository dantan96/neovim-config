return {
  "tpope/vim-obsession",
  event = "VeryLazy",
  init = function()
    -- What gets saved in sessions (tweak to taste)
    -- See :h 'sessionoptions'
    vim.opt.sessionoptions = {
      "buffers", -- listed buffers
      "curdir", -- current directory
      "folds", -- folds
      "help", -- help windows
      "tabpages", -- all tab pages
      "winsize", -- window sizes
      "winpos", -- window positions (GUI/kitty-only effect)
      "terminal", -- terminal buffers
      "localoptions", -- local window/buf options
    }

    -- in the same plugin spec's config/init, or anywhere in your config
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        -- If Obsession isn't already active…
        if vim.g.this_obsession == nil then
          local root = vim.fn.getcwd()
          -- opt-in sentinel: start only if ".obsession" exists in the project root
          if vim.uv.fs_stat(root .. "/.obsession") then
            vim.cmd("silent! Obsession")
          end
        end
      end,
    })
  end,
  keys = {
    { "<leader>os", "<cmd>Obsession<cr>", desc = "Obsession: start/resume" },
    { "<leader>oS", "<cmd>Obsession!<cr>", desc = "Obsession: stop & delete" },
  },
  config = function()
    -- -- Sync statusline if desired:
    -- vim.opt.statusline:append("%{ObsessionStatus()}")

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsessionStart",
      callback = function()
        local f = io.open(".obsession", "w")
        if f then
          f:write("obsession started at " .. os.date() .. "\n")
          f:close()
        end
      end,
    })
  end,
}
