-- Markdown export commands.
--
-- Commands:
--   :ExportHTML        – export to HTML with MathJax via pandoc
--   :ExportToGippity   – copy buffer as LaTeX delimiters to clipboard

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("ExportHTML", function()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
      vim.notify(
        "No file found — save buffer before exporting",
        vim.log.levels.ERROR
      )
      return
    end

    local output = file:gsub("%.%w+$", ".html")

    local cmd = {
      "pandoc",
      "-s",
      "--from=markdown+tex_math_single_backslash",
      "--to=html5",
      "--mathjax",
      "-o",
      output,
      file,
    }

    local result = vim.fn.system(cmd)
    local code = vim.v.shell_error
    if code == 0 then
      vim.notify("Exported HTML ➤ " .. output, vim.log.levels.INFO)
    else
      vim.notify("pandoc failed: " .. result, vim.log.levels.ERROR)
    end
  end, {
    desc = "Export current markdown to HTML with math via pandoc",
  })

  vim.api.nvim_create_user_command("ExportToGippity", function()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = table.concat(lines, "\n")

    local out = vim.fn.systemlist({ "mathdelim.py", "--to-latex" }, input)
    if vim.v.shell_error ~= 0 then
      vim.notify(
        ("ExportToGippity: mathdelim.py failed (exit %d)"):format(vim.v.shell_error),
        vim.log.levels.ERROR
      )
      return
    end

    local result = table.concat(out, "\n")
    vim.fn.setreg('"', result)
    vim.fn.setreg("+", result)
    vim.notify(
      ("Converted to LaTeX delimiters and copied to clipboard (%d lines)."):format(#out),
      vim.log.levels.INFO
    )
  end, {
    desc = "Copy buffer as LaTeX-style math to clipboard (buffer unchanged)",
  })
end

return M
