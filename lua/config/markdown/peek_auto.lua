-- Auto-open Peek viewer for markdown files containing LaTeX delimiters.

local M = {}

function M.has_latex(text)
  return (
    text:match("\\%(")
    or text:match("\\%[")
    or text:match("%$%$[^%$]+%$%$")
    or text:match("%$[^%$]+%$")
  ) ~= nil
end

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*.md",
    callback = function()
      if vim.b.peek_triggered then
        return
      end

      local text =
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

      if M.has_latex(text) then
        vim.b.peek_triggered = true
        pcall(vim.cmd, "Markview Stop")
        if pcall(require, "peek") then
          require("peek").open()
        end
      end
    end,
  })
end

return M
