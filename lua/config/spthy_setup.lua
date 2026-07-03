-- spthy_setup.lua
-- A streamlined setup for Tamarin Security Protocol Theory (.spthy) files
-- This replaces the multiple files that were previously used

local M = {}

-- Setup function
function M.setup()
  -- 1. Register filetype directly in Neovim
  vim.filetype.add({
    extension = {
      spthy = "spthy",
      sapic = "spthy"
    },
  })

  -- The spthy parser lives at <config>/parser/spthy.so; the config dir is
  -- already on the runtimepath, so Neovim finds it natively. The filetype
  -- ('spthy') equals the treesitter language name, so no
  -- vim.treesitter.language.register() call is needed either.

  -- 2. Setup highlights for spthy files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "spthy",
    callback = function()
      -- Make sure tamarin-colors is loaded first
      local tc = require("config.tamarin-colors")
      tc.setup()

      -- Explicitly enable TreeSitter for this buffer
      local ok, err = pcall(vim.treesitter.start, 0, "spthy")
      if not ok and not M._warned then
        M._warned = true
        vim.notify(
          "spthy: treesitter highlighting unavailable: " .. tostring(err),
          vim.log.levels.WARN
        )
      end

      local highlights = tc.highlights
      for group, color in pairs(highlights) do
        local groupSuffix = string.sub(group, 2)
        local spthyGroup = "@spthy" .. groupSuffix
        vim.api.nvim_set_hl(0, spthyGroup, color)
      end
    end,
  })

  return true
end

return M
