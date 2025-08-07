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
vim.api.nvim_set_hl(
  0,
  "@keyword.modifier.fsharp",
  { fg = "#f2cdcd", bold = true }
)
vim.api.nvim_set_hl(
  0,
  "@module.builtin.fsharp",
  { fg = "#f9e2af", underline = false, italic = true }
)
vim.api.nvim_set_hl(
  0,
  "@lsp.type.module.fsharp",
  { fg = "#f9e2af", underline = false, italic = true }
)
vim.api.nvim_set_hl(
  0,
  "@lsp.type.namespace.fsharp",
  { fg = "#f9e2af", underline = false, italic = true }
)
-- Remove underline and faded color for DiagnosticUnnecessary
vim.api.nvim_set_hl(
  0,
  "DiagnosticUnnecessary",
  { underline = nil, fg = nil, bg = nil, default = false }
)
vim.api.nvim_set_hl(
  0,
  "@variable.enum_member.fsharp",
  { fg = "#f5c2e7", underline = true }
)
-- vim.api.nvim_set_hl(0, "@punctuation.delimiter.fsharp", { priority = 150 })

---------------------------------------------------------------------------
-- ==========  F# Interactive helper (Alt-Enter, Alt-@)  ==========
---------------------------------------------------------------------------

-- Only define once per Neovim session
if not vim.g._fsharp_fsi_loaded then
  vim.g._fsharp_fsi_loaded = true

  local fsi = { buf = nil, win = nil, job = nil }

  local function is_running()
    return fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1 -- -1 → still running
  end

  local function open_fsi(focus)
    local just_started = false

    -- spawn if job dead OR window closed
    if not is_running() or not vim.api.nvim_win_is_valid(fsi.win or -1) then
      local original_win = vim.api.nvim_get_current_win()
      vim.cmd("belowright 15split term://dotnet fsi")
      fsi.win = vim.api.nvim_get_current_win()
      fsi.buf = vim.api.nvim_get_current_buf()
      fsi.job = vim.b.terminal_job_id
      just_started = true
      vim.opt_local.number, vim.opt_local.relativenumber = false, false

      if not focus then
        vim.schedule(function()
          vim.fn.win_gotoid(original_win)
        end)
      end

      -- clear saved state when user :q or job exits
      vim.api.nvim_create_autocmd({ "TermClose", "BufWipeout" }, {
        buffer = fsi.buf,
        once = true,
        callback = function()
          if fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1 then
            vim.fn.jobstop(fsi.job)
          end
          fsi = { buf = nil, win = nil, job = nil }
        end,
      })
    elseif vim.api.nvim_win_is_valid(fsi.win) then
      vim.api.nvim_win_call(fsi.win, function()
        vim.cmd("normal! G")
      end)
    end

    return just_started
  end

  local function send(lines)
    local fresh = open_fsi(false) -- never focus on Alt‑Enter
    local nl = vim.bo.fileformat == "dos" and "\r\n" or "\n"

    -- build the text exactly like Ionide: optionally cd, then the whole block
    local current_dir = vim.fn.expand("%:p:h")
    local prefix = ""
    if current_dir ~= "" and vim.fn.isdirectory(current_dir) == 1 then
      prefix = '#cd @"' .. current_dir .. '"' .. nl
    end
    local text = table.concat(lines, nl)
    local payload = prefix .. text .. nl .. ";;" .. nl

    if fresh then
      vim.wait(1000, function()
        return vim.fn.jobwait({ fsi.job }, 0)[1] == -1
      end)
    end
    vim.api.nvim_chan_send(fsi.job, payload)
  end

  function _FSharpEvalLineOrVisual()
    local mode = vim.fn.mode()
    local lines

    if mode:match("[vV]") then
      local s = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
      local e = vim.api.nvim_buf_get_mark(0, ">")[1]
      lines = vim.api.nvim_buf_get_lines(0, s, e, false)
      vim.cmd("normal! \\<Esc>")
    else
      local row = vim.api.nvim_win_get_cursor(0)[1]
      lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
    end

    send(lines)

    vim.schedule(function()
      if mode:match("[vV]") then
        vim.cmd("normal! " .. #lines .. "j")
      else
        vim.cmd("normal! j")
      end
    end)
  end
  function _FSharpToggleFsi()
    if is_running() and vim.api.nvim_win_is_valid(fsi.win) then
      vim.api.nvim_win_close(fsi.win, true)
      fsi.win = nil
    else
      open_fsi(true)
    end
  end

  -- Expose a :FsiShow command like Ionide
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
    -- 2.  Attach Alt-Enter / Alt-@ for **this buffer**      ← NEW
    --------------------------------------------------------------------
    local map_opts = { buffer = args.buf, desc = "F# Interactive" }
    vim.keymap.set({ "n", "v" }, "<M-CR>", _FSharpEvalLineOrVisual, map_opts)
    vim.keymap.set("n", "<M-@>", _FSharpToggleFsi, map_opts)
  end,
})
