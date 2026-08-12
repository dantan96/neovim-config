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

local did_setup = false

function M.setup()
  -- Idempotent: setup() is called from after/ftplugin/markdown.lua for
  -- every markdown buffer; only register the autocmd once.
  if did_setup then
    return
  end
  did_setup = true

  local aug = vim.api.nvim_create_augroup("PeekAutoOpen", { clear = true })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = aug,
    pattern = "*.md",
    callback = function()
      if vim.b.peek_triggered then
        return
      end

      local text =
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

      if M.has_latex(text) then
        vim.b.peek_triggered = true
        -- Stop markview rendering only if the plugin is actually loaded.
        -- It is lazy-loaded on keys, so usually it is not; calling the
        -- command unconditionally would just silently fail via pcall.
        if package.loaded["markview"] then
          -- Wrapped: `vim.cmd` is a callable table, not a function.
          pcall(function()
            vim.cmd("Markview Stop")
          end)
        end
        if pcall(require, "peek") then
          require("peek").open()
        end
      end
    end,
  })
end

return M
