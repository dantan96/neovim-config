-- Toggle state for the gd detail-columns keymap below.
local detail = false

return {
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      keymaps = {
        ["gd"] = {
          desc = "Toggle file detail view",
          callback = function()
            detail = not detail
            if detail then
              require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
            else
              require("oil").set_columns({ "icon" })
            end
          end,
        },
      },
    },
    -- Icons come from the echasnovski/mini.nvim suite (see mini.lua); a
    -- standalone mini.icons dependency here would put it on the rtp twice.
  }
}
