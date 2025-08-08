-- luacheck: globals vim _FSharpToggleFsi
-- Indentation for F#
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4
vim.opt_local.autoindent = false
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

-- UI tweaks (yours)
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
  { fg = "#f9e2af", italic = true }
)
vim.api.nvim_set_hl(
  0,
  "@lsp.type.module.fsharp",
  { fg = "#f9e2af", italic = true }
)
vim.api.nvim_set_hl(
  0,
  "@lsp.type.namespace.fsharp",
  { fg = "#f9e2af", italic = true }
)
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

---------------------------------------------------------------------------
-- ==========  F# Interactive helper (Alt-Enter, Alt-@)  ==========
---------------------------------------------------------------------------

if not vim.g._fsharp_fsi_loaded then
  vim.g._fsharp_fsi_loaded = true

  local fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
  local LOG_PATH = vim.fn.stdpath("state") .. "/fsi.log"

  local function ensure_logdir()
    local dir = vim.fn.fnamemodify(LOG_PATH, ":h")
    if vim.fn.isdirectory(dir) == 0 then
      pcall(vim.fn.mkdir, dir, "p")
    end
  end

  local function log(msg, ...)
    ensure_logdir()
    local s = ("[FSI] " .. msg):format(...)
    pcall(vim.fn.writefile, { os.date("!%F %T") .. " " .. s }, LOG_PATH, "a")
    -- add_to_history=true so :messages shows them
    vim.api.nvim_echo({ { s, "Comment" } }, true, {})
  end

  local function running()
    return fsi.job and vim.fn.jobwait({ fsi.job }, 0)[1] == -1
  end

  --- Open/ensure FSI in its own new buffer. Optionally keep focus in REPL.
  --- @param keep_focus_in_repl boolean
  --- @return boolean just_started
  local function open_fsi(keep_focus_in_repl)
    local just_started = false
    local original_win = vim.api.nvim_get_current_win()

    if not running() or not vim.api.nvim_win_is_valid(fsi.win or -1) then
      -- NEW, empty buffer so we never clobber the source buffer
      vim.cmd("botright 15new")
      fsi.win = vim.api.nvim_get_current_win()
      fsi.buf = vim.api.nvim_get_current_buf()

      local jid = vim.fn.jobstart({ "dotnet", "fsi" }, { term = true }) -- Neovim 0.12
      if type(jid) ~= "number" or jid <= 0 then
        vim.api.nvim_echo(
          { { "Failed to start FSI.", "ErrorMsg" } },
          true,
          { err = true }
        )
        return false
      end

      fsi.job, fsi.sent_cd = jid, false
      vim.bo.bufhidden = "wipe"
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      just_started = true
      log(
        "open_fsi: win=%s buf=%s job=%s",
        tostring(fsi.win),
        tostring(fsi.buf),
        tostring(fsi.job)
      )

      if
        not keep_focus_in_repl and vim.api.nvim_win_is_valid(original_win)
      then
        vim.fn.win_gotoid(original_win)
        log("open_fsi: returned focus to original window=%d", original_win)
      end

      -- Cleanup
      vim.api.nvim_create_autocmd({ "TermClose", "BufWipeout" }, {
        buffer = fsi.buf,
        once = true,
        callback = function()
          log("cleanup: terminal closed/wiped")
          if running() then
            pcall(vim.fn.jobstop, fsi.job)
          end
          fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
        end,
      })
      vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(fsi.win),
        once = true,
        callback = function()
          log("cleanup: window closed")
          if running() then
            pcall(vim.fn.jobstop, fsi.job)
          end
          fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
        end,
      })
    else
      if vim.api.nvim_buf_is_valid(fsi.buf) then
        vim.api.nvim_buf_call(fsi.buf, function()
          vim.cmd("normal! G")
        end)
      end
    end

    return just_started
  end

  local function send_lines(lines)
    local just_started = open_fsi(false) -- keep focus in code
    local nl = (vim.bo.fileformat == "dos") and "\r\n" or "\n"

    if not lines or #lines == 0 then
      log("send: empty payload; skipping")
      return
    end

    local txt = table.concat(lines, nl)
    if #txt:gsub("%s+", "") == 0 then
      log("send: whitespace-only payload; skipping")
      return
    end

    local payload = ""
    if just_started and not fsi.sent_cd then
      local dir = vim.fn.expand("%:p:h")
      if dir ~= "" and vim.fn.isdirectory(dir) == 1 then
        payload = '#cd @"' .. dir .. '"' .. nl
      end
      fsi.sent_cd = true
      log("send: issued #cd for dir=%s", dir)
    end

    payload = payload .. txt .. nl .. ";;" .. nl
    log("send: bytes=%d", #payload)

    local function do_send()
      if not running() then
        log("send: job not running; abort")
        return
      end
      local ok, err = pcall(vim.fn.chansend, fsi.job, payload)
      log("send: chansend ok=%s err=%s", tostring(ok), err or "nil")
    end

    if just_started then
      -- Tiny tick so first prompt/echo is visible (terminal is async)
      vim.defer_fn(do_send, 70)
    else
      do_send()
    end
  end

  -- ---------- CRITICAL CHANGE: range-driven command ----------
  -- Using a user command with -range ensures line1/line2 are ALWAYS valid.
  -- When invoked from Visual via ":" Neovim inserts :'<,'> automatically.
  vim.api.nvim_create_user_command("FsiSend", function(args)
    local s, e = args.line1, args.line2
    local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
    log("FsiSend: range %d..%d count=%d", s, e, #lines)
    send_lines(lines)
    -- Reselect if a range was provided (keep Visual selection for repeated sends)
    if args.range and args.range > 0 then
      vim.schedule(function()
        pcall(vim.cmd, "normal! gv")
      end)
    end
  end, { range = true })

  -- Debug helpers
  vim.api.nvim_create_user_command("FsiShow", function()
    open_fsi(false)
  end, {})
  vim.api.nvim_create_user_command("FsiStatus", function()
    log(
      "STATUS: win=%s buf=%s job=%s running=%s sent_cd=%s log=%s",
      tostring(fsi.win),
      tostring(fsi.buf),
      tostring(fsi.job),
      tostring(running()),
      tostring(fsi.sent_cd),
      LOG_PATH
    )
  end, {})
  vim.api.nvim_create_user_command("FsiSelfTest", function()
    local tag = ("NVTAG-%d"):format(math.random(10 ^ 8, 10 ^ 9 - 1))
    send_lines({ ('printfn "%s"'):format(tag) })
    vim.defer_fn(function()
      if fsi.buf and vim.api.nvim_buf_is_valid(fsi.buf) then
        local ok = false
        for _, L in ipairs(vim.api.nvim_buf_get_lines(fsi.buf, 0, -1, false)) do
          if L:find(tag, 1, true) then
            ok = true
            break
          end
        end
        log(
          "SelfTest: %s",
          ok and "PASS (tag found)" or "FAIL (tag not found)"
        )
      end
    end, 250)
  end, {})
  vim.api.nvim_create_user_command("FsiOpenLog", function()
    ensure_logdir()
    vim.cmd("tabnew " .. vim.fn.fnameescape(LOG_PATH))
  end, {})

  -- Optional explicit toggle
  _G._FSharpToggleFsi = function()
    if running() and vim.api.nvim_win_is_valid(fsi.win or -1) then
      if fsi.job and running() then
        pcall(vim.fn.jobstop, fsi.job)
      end
      if vim.api.nvim_win_is_valid(fsi.win) then
        pcall(vim.api.nvim_win_close, fsi.win, true)
      end
      fsi = { buf = nil, win = nil, job = nil, sent_cd = false }
      log("ToggleFsi: stopped")
    else
      local started = open_fsi(true)
      log("ToggleFsi: started=%s", tostring(started))
    end
  end
end

-- LSP boot (unchanged aside from mappings below)
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
      or vim.fs.dirname(fname)

    vim.lsp.start({
      name = "fsautocomplete",
      cmd = { "fsautocomplete" },
      filetypes = { "fsharp", "fs", "fsx", "fsi" },
      root_dir = root,
      init_options = { AutomaticWorkspaceInit = true },
    })

    vim.cmd("runtime! syntax/fsharp.vim")
    vim.fn.clearmatches()
    vim.fn.matchadd("fsharpOperator", "::", 150)
    vim.fn.matchadd("Operator", "::", 200)

    -- Mappings: use Ex so Visual gets :'<,'> automatically; no Lua mark timing.
    local map_opts = { buffer = args.buf, desc = "F# Interactive" }
    vim.keymap.set("n", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Normal: current line
    vim.keymap.set("x", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Visual: current selection
    vim.keymap.set("n", "<M-@>", _FSharpToggleFsi, map_opts)
  end,
})
