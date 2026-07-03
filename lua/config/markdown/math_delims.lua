-- Math delimiter conversion and export commands.
--
-- Commands:
--   :MathDelimsToDollars  – pandoc-based \(…\)/\[…\] → $…$/$$…$$
--   :DelimToggle          – auto-detect and toggle via mathdelim.py
--   :DelimDollars         – force to dollar style
--   :DelimParens          – force to LaTeX style
--
-- (:ExportToGippity lives in config.markdown.export and reuses
-- M.run_mathdelim from this module.)
--
-- Auto-save: BufWritePre converts \( / \[ → $ on markdown files (warns on
-- failure; opt out per buffer with vim.b.mathdelim_disable = true).

local M = {}

-- Convert \(..\), \[..] math delimiters to $..$, $$..$$ using pandoc.
local function math_delims_to_dollars()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, "\n")

  local cmd = {
    "pandoc",
    "--from=markdown+tex_math_single_backslash",
    "--to=markdown+tex_math_dollars",
    "--wrap=preserve",
    "--eol=lf",
  }

  local out = vim.fn.systemlist(cmd, input)
  local code = vim.v.shell_error

  if code ~= 0 then
    vim.notify(
      ("pandoc failed (exit %d). Is pandoc installed and on $PATH?"):format(code),
      vim.log.levels.ERROR
    )
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.notify(
    "Converted \\(\\)/\\[\\] math delimiters to $/$$ via pandoc.",
    vim.log.levels.INFO
  )
end

--- Run `mathdelim.py [args…]` on a buffer's contents.
---@param args string[]|nil  extra CLI arguments
---@param opts { buf?: integer, write?: boolean }|nil
---  buf:   buffer to read (default: current)
---  write: replace the buffer with the output on success (default: true)
---@return string[]|nil out  output lines on success, nil on failure
---  (a WARN notification is emitted on failure)
function M.run_mathdelim(args, opts)
  args = args or {}
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, "\n")
  local cmd = vim.list_extend({ "mathdelim.py" }, args)
  local out = vim.fn.systemlist(cmd, input)
  if vim.v.shell_error ~= 0 then
    local hint = (#args == 0) and "; use :DelimDollars or :DelimParens" or ""
    vim.notify(
      ("mathdelim: conversion failed (exit %d)%s"):format(vim.v.shell_error, hint),
      vim.log.levels.WARN
    )
    return nil
  end
  if opts.write ~= false then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  end
  return out
end

local run_mathdelim = M.run_mathdelim

function M.setup()
  vim.api.nvim_create_user_command(
    "MathDelimsToDollars",
    math_delims_to_dollars,
    { desc = "Convert \\(\\)/\\[\\] math delimiters to $/$$ using pandoc" }
  )

  vim.api.nvim_create_user_command("DelimToggle", function()
    if run_mathdelim({}) then
      vim.notify("Math delimiters toggled.", vim.log.levels.INFO)
    end
  end, {
    desc = "Auto-detect dominant delimiter style and toggle to the other",
  })

  vim.api.nvim_create_user_command("DelimDollars", function()
    if run_mathdelim({ "--to-dollar" }) then
      vim.notify("Converted math delimiters → $…$ / $$…$$", vim.log.levels.INFO)
    end
  end, {
    desc = "Convert math delimiters to dollar style ($…$ / $$…$$)",
  })

  vim.api.nvim_create_user_command("DelimParens", function()
    if run_mathdelim({ "--to-latex" }) then
      vim.notify("Converted math delimiters → \\(…\\) / \\[…\\]", vim.log.levels.INFO)
    end
  end, {
    desc = "Convert math delimiters to LaTeX style (\\(…\\) / \\[…\\])",
  })

  -- On every save: convert LaTeX-style delimiters to dollars, warning on
  -- failure. Set vim.b.mathdelim_disable = true to skip for a buffer.
  -- (mathdelim.py itself is markdown-it based and leaves fenced code
  -- blocks untouched, so a \( inside a fence only costs a no-op run.)
  local aug =
    vim.api.nvim_create_augroup("MarkdownMathDelims", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = aug,
    pattern = { "*.md", "*.markdown", "*.mdx" },
    callback = function(ev)
      if vim.b[ev.buf].mathdelim_disable then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      local text = table.concat(lines, "\n")
      if not (text:find("\\%(") or text:find("\\%[")) then
        return
      end
      run_mathdelim({ "--to-dollar" }, { buf = ev.buf })
    end,
  })
end

return M
