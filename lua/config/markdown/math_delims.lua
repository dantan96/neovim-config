-- Math delimiter conversion and export commands.
--
-- Commands:
--   :MathDelimsToDollars  – pandoc-based \(…\)/\[…\] → $…$/$$…$$
--   :DelimToggle          – auto-detect and toggle via mathdelim.py
--   :DelimDollars         – force to dollar style
--   :DelimParens          – force to LaTeX style
--   :ExportToGippity      – copy buffer as LaTeX delimiters to clipboard
--
-- Auto-save: BufWritePre silently converts \( / \[ → $ on markdown files.

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

--- Run `mathdelim.py [args…]` on buf in-place.
--- Returns true on success, false on failure.
local function run_mathdelim(args, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, "\n")
  local cmd = vim.list_extend({ "mathdelim.py" }, args or {})
  local out = vim.fn.systemlist(cmd, input)
  if vim.v.shell_error ~= 0 then
    local hint = (#args == 0) and "; use :DelimDollars or :DelimParens" or ""
    vim.notify(
      ("mathdelim: conversion failed (exit %d)%s"):format(vim.v.shell_error, hint),
      vim.log.levels.WARN
    )
    return false
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  return true
end

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

  -- On every save: silently convert LaTeX-style delimiters to dollars
  local aug =
    vim.api.nvim_create_augroup("MarkdownMathDelims", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = aug,
    pattern = { "*.md", "*.markdown", "*.mdx" },
    callback = function(ev)
      local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      local text = table.concat(lines, "\n")
      if not (text:find("\\%(") or text:find("\\%[")) then
        return
      end
      local out = vim.fn.systemlist({ "mathdelim.py", "--to-dollar" }, text)
      if vim.v.shell_error == 0 then
        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, out)
      end
    end,
  })
end

return M
