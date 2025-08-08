-- luacheck: globals vim _FSharpEvalLineOrVisual _FSharpToggleFsi
-- Use spaces for indentation in F# (required by lightweight syntax)
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4

-- Optional: make tabs visible while editing
-- vim.opt_local.list = true
-- vim.opt_local.listchars:append({ tab = "» " })

vim.opt_local.autoindent = false
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

vim.api.nvim_set_hl(0, "@enum.member.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@lsp.type.enumMember.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(0, "@lsp.type.operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(0, "@keyword.modifier.fsharp", { fg = "#f2cdcd", bold = true })
vim.api.nvim_set_hl(0, "@module.builtin.fsharp", { fg = "#f9e2af", underline = false, italic = true })
vim.api.nvim_set_hl(0, "@lsp.type.module.fsharp", { fg = "#f9e2af", underline = false, italic = true })
vim.api.nvim_set_hl(0, "@lsp.type.namespace.fsharp", { fg = "#f9e2af", underline = false, italic = true })
-- Remove underline and faded color for DiagnosticUnnecessary
vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { underline = nil, fg = nil, bg = nil, default = false })
vim.api.nvim_set_hl(0, "@variable.enum_member.fsharp", { fg = "#f5c2e7", underline = true })
-- vim.api.nvim_set_hl(0, "@punctuation.delimiter.fsharp", { priority = 150 })

---------------------------------------------------------------------------
-- ==========  F# Interactive helper (Alt-Enter, Alt-@)  ==========
---------------------------------------------------------------------------

-- Only define once per Neovim session
if not vim.g._fsharp_fsi_loaded then
  vim.g._fsharp_fsi_loaded = true

  local fsi = { buf = nil, win = nil, job = nil, sent_cd = false }

  local function is_running()
    return fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1 -- -1 → still running
  end

  ---Open (or ensure) FSI in a split. Optionally keep focus in the REPL.
  ---@param keep_focus_in_repl boolean
  ---@return boolean just_started, integer original_win
  local function open_fsi(keep_focus_in_repl)
    local just_started = false
    local original_win = vim.api.nvim_get_current_win()

    -- spawn if job dead OR window closed
    if not is_running() or not vim.api.nvim_win_is_valid(fsi.win or -1) then
      vim.cmd("belowright 15split term://dotnet fsi")
      fsi.win = vim.api.nvim_get_current_win()
      fsi.buf = vim.api.nvim_get_current_buf()
      fsi.job = vim.b.terminal_job_id
      fsi.sent_cd = false
      vim.bo.bufhidden = "wipe"
      just_started = true
      vim.opt_local.number, vim.opt_local.relativenumber = false, false

      if not keep_focus_in_repl then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(original_win) then
            vim.fn.win_gotoid(original_win)
          end
        end)
      end

      -- clear saved state when window closes or job exits
      vim.api.nvim_create_autocmd({ "TermClose", "BufWipeout" }, {
        buffer = fsi.buf,
        once = true,
        callback = function()
          if fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1 then
            pcall(vim.fn.jobstop, fsi.job)
          end
          fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
        end,
      })

      vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(fsi.win),
        once = true,
        callback = function()
          if fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1 then
            pcall(vim.fn.jobstop, fsi.job)
          end
          fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
        end,
      })
    elseif vim.api.nvim_buf_is_valid(fsi.buf) then
      -- keep the terminal scrolled to bottom if it already existed
      vim.api.nvim_buf_call(fsi.buf, function()
        vim.cmd("normal! G")
      end)
    end

    return just_started, original_win
  end

  ---Send a list of lines to FSI, appending ';;' and a newline.
  ---Sends '#cd "…"' exactly once per FSI session (on first start).
  local function send(lines)
    local just_started, _ = open_fsi(false) -- keep focus in code window
    local nl = vim.bo.fileformat == "dos" and "\r\n" or "\n"

    local text = table.concat(lines or {}, nl)
    if (#lines == 0) or (#lines == 1 and text:match("^%s*$")) then
      return
    end

    local payload = ""

    -- Only send #cd once per FSI session
    if just_started and not fsi.sent_cd then
      local current_dir = vim.fn.expand("%:p:h")
      if current_dir ~= "" and vim.fn.isdirectory(current_dir) == 1 then
        payload = '#cd @"' .. current_dir .. '"' .. nl
      end
      fsi.sent_cd = true
    end

    payload = payload .. text .. nl .. ";;" .. nl
    vim.fn.chansend(fsi.job, payload)
  end

  function _FSharpEvalLineOrVisual()
    local m = vim.fn.mode()
    local lines

    if m == "v" or m == "V" or m == "\022" then -- charwise/linewise/blockwise visual
      local s = vim.fn.getpos("'<")
      local e = vim.fn.getpos("'>")
      local srow, scol = s[2], s[3]
      local erow, ecol = e[2], e[3]

      local raw = vim.api.nvim_buf_get_lines(0, srow - 1, erow, false)
      if #raw == 0 then return end

      -- Trim to visual column bounds (inclusive)
      raw[1] = string.sub(raw[1], math.max(scol, 1))
      raw[#raw] = string.sub(raw[#raw], 1, ecol)

      lines = raw

      -- leave visual mode
      local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      vim.api.nvim_feedkeys(esc, "n", false)
    else
      local row = vim.api.nvim_win_get_cursor(0)[1]
      lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
    end

    send(lines)

    -- Move cursor down one line after sending (Ionide-like nicety)
    vim.schedule(function()
      pcall(vim.cmd, "normal! j")
    end)
  end

  function _FSharpToggleFsi()
    if is_running() and vim.api.nvim_win_is_valid(fsi.win or -1) then
      if fsi.job then
        pcall(vim.fn.jobstop, fsi.job)
      end
      if vim.api.nvim_win_is_valid(fsi.win) then
        pcall(vim.api.nvim_win_close, fsi.win, true)
      end
      fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
    else
      open_fsi(true) -- open and keep focus in the REPL
    end
  end

  -- Expose a :FsiShow command like Ionide (open FSI but keep focus in code)
  vim.api.nvim_create_user_command("FsiShow", function()
    open_fsi(false)
  end, {})
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "fsharp", "fs", "fsx", "fsi" },
  callback = function(args)
    -- Don’t start a second client if one is already active
    for _, client in pairs(vim.lsp.get_clients({ bufnr = args.buf })) do
      if client.name == "fsautocomplete" then
        return
      end
    end

    local fname = vim.api.nvim_buf_get_name(args.buf)
    local util = require("lspconfig.util")
    local root = util.root_pattern("*.sln", "*.fsproj", ".git")(fname)
    if not root then
      root = vim.fs.dirname(fname) -- fallback to the file’s directory
    end

    vim.lsp.start({
      name = "fsautocomplete",
      cmd = { "fsautocomplete" },
      filetypes = { "fsharp", "fs", "fsx", "fsi" },
      root_dir = root,
      init_options = { AutomaticWorkspaceInit = true },
    })
    vim.cmd("runtime! syntax/fsharp.vim")
    -- Clear any previous matches in this buffer (optional)
    vim.fn.clearmatches()

    -- Add a new high-priority match for "::"
    -- Args:       group           pattern  priority
    vim.fn.matchadd("fsharpOperator", "::", 150)
    vim.fn.matchadd("Operator", "::", 200)

    --------------------------------------------------------------------
    -- 2.  Attach Alt-Enter / Alt-@ for **this buffer**
    --------------------------------------------------------------------
    local map_opts = { buffer = args.buf, desc = "F# Interactive" }
    vim.keymap.set({ "n", "v" }, "<M-CR>", _FSharpEvalLineOrVisual, map_opts)
    vim.keymap.set("n", "<M-@>", _FSharpToggleFsi, map_opts)
  end,
})
