-- lua/config/fsharp/splitter.lua
-- Buffer command to split long F# string literals to max_line_length
-- (logic lives in custom.fsharp_helpers), plus a global command to view
-- the splitter's log.

local M = {}

--- Create the buffer-local :FSharpSplitStrings command for `bufnr`.
function M.attach(bufnr)
  vim.api.nvim_buf_create_user_command(bufnr, "FSharpSplitStrings", function()
    local helpers = require("custom.fsharp_helpers")
    local buf = vim.api.nvim_get_current_buf()
    local new_lines = helpers.split_long_strings_in_buffer(buf)
    if new_lines then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
      vim.notify("FSharp: long strings split.", vim.log.levels.INFO)
    else
      vim.notify("FSharp: no strings needed splitting.", vim.log.levels.INFO)
    end
  end, { desc = "Split long F# string literals to fit max_line_length" })
end

-- Session-global guard (vim.g, not a module-local): `:source %` of
-- this file runs a FRESH chunk whose local guard is false, so a
-- module-local flag would let setup() re-run and reset module state
-- (the <space><space>x mapping makes that a real workflow).
function M.setup()
  if vim.g._fsharp_splitter_setup then
    return
  end
  vim.g._fsharp_splitter_setup = true

  vim.api.nvim_create_user_command("FSharpSplitterLog", function()
    local log_path = vim.fn.stdpath("state") .. "/fsharp_string_splitter.log"
    if vim.fn.filereadable(log_path) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(log_path))
    else
      vim.notify("F# Splitter log file not found.", vim.log.levels.WARN)
    end
  end, { desc = "Open the F# string splitter log file" })
end

return M
