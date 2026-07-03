-- lua/config/fsharp/editorconfig.lua
-- :FSharpEnsureEditorConfig — create a suitable .editorconfig at the
-- project root if none exists up the tree (bang variant also opens it).

local M = {}

local function write_editorconfig(path)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    pcall(vim.fn.mkdir, dir, "p")
  end
  local lines = {
    "root = true",
    "",
    "[*]",
    "end_of_line = lf",
    "charset = utf-8",
    "insert_final_newline = true",
    "trim_trailing_whitespace = true",
    "indent_style = space",
    "",
    "[*.{fs,fsx,fsi}]",
    "dotnet_diagnostic.FSAC0004.severity = none",
    "indent_size = 4",
    "max_line_length = 79",
    "",
  }
  vim.fn.writefile(lines, path)
end

local done = false

function M.setup()
  if done then
    return
  end
  done = true

  local helpers = require("custom.fsharp_helpers")

  vim.api.nvim_create_user_command("FSharpEnsureEditorConfig", function(args)
    local root = helpers.project_root()
    local existing = helpers.find_editorconfig(root)

    if existing then
      if args.bang then
        vim.cmd.edit(vim.fn.fnameescape(existing))
      end
      return
    end
    local path = root .. "/.editorconfig"
    write_editorconfig(path)
    if args.bang then
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
  end, {
    bang = true,
    desc = "Ensure .editorconfig exists for the F# project (use ! to open it)",
  })
end

return M
