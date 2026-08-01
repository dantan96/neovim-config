-- Default formatting OFF for buffers prettier itself would ignore.
--
-- Replaces a hardcoded directory list: projects opt out of markdown
-- formatting by shipping a .prettierignore (e.g. ~/ResumeProject,
-- whose build script parses the markdown line-by-line), and nvim
-- asks prettier — `prettier --file-info` reports `ignored` — instead
-- of re-implementing glob matching.
--
-- Prettier resolves .prettierignore relative to its CWD ONLY (no
-- upward walk, unlike .prettierrc), so the probe must run from the
-- directory that holds the ignore file; plugins/format.lua points
-- conform's prettier cwd at the same root so save-format agrees.
--
-- The probe is async and merely defaults vim.b.disable_autoformat on;
-- <leader>tf still overrides per buffer, and the same flag gates
-- format-on-pause (config.markdown.pauseformat), so ignored buffers
-- never spawn a pause run at all.

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    group = vim.api.nvim_create_augroup("prettier-ignore-probe", { clear = true }),
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if name == "" then
        return
      end
      local root = vim.fs.root(name, ".prettierignore")
      if not root then
        return
      end
      local prettier = vim.fn.exepath("prettier")
      if prettier == "" then
        return
      end
      local rel = vim.fs.relpath(root, name)
      if not rel then
        return
      end
      vim.system(
        { prettier, "--file-info", rel },
        { cwd = root, text = true },
        vim.schedule_wrap(function(out)
          if out.code ~= 0 or not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end
          local ok, info = pcall(vim.json.decode, out.stdout)
          if ok and info.ignored then
            vim.b[args.buf].disable_autoformat = true
          end
        end)
      )
    end,
  })
end

return M
