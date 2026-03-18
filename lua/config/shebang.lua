local M = {}

-- Edit this table to customise the shebang inserted per filetype.
-- The default fallback applies to any filetype not listed here.
M.shebangs = {
  python     = "#!/usr/bin/env python3.14",
  sh         = "#!/usr/bin/env bash",
  bash       = "#!/usr/bin/env bash",
  zsh        = "#!/usr/bin/env zsh",
  javascript = "#!/usr/bin/env node",
  typescript = "#!/usr/bin/env npx ts-node",
  ruby       = "#!/usr/bin/env ruby",
  perl       = "#!/usr/bin/env perl",
  lua        = "#!/usr/bin/env lua",
}
M.default = "#!/usr/bin/env sh"

function M.insert()
  local first = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
  if first:match("^#!") then
    vim.notify("shebang already present", vim.log.levels.WARN)
    return
  end
  local shebang = M.shebangs[vim.bo.filetype] or M.default
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { shebang })
  local fname = vim.api.nvim_buf_get_name(0)
  if fname ~= "" then
    vim.system({ "chmod", "+x", fname })
  end
end

function M.setup()
  vim.keymap.set("n", "<leader>S", M.insert, { desc = "Insert shebang" })
end

return M
