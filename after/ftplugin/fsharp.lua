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

  -- Silent file logging only (no echo)
  local function log(msg, ...)
    ensure_logdir()
    local s = ("[FSI] " .. msg):format(...)
    pcall(vim.fn.writefile, { os.date("!%F %T") .. " " .. s }, LOG_PATH, "a")
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

      -- Neovim 0.12 terminal job
      local jid = vim.fn.jobstart({ "dotnet", "fsi" }, { term = true })
      if type(jid) ~= "number" or jid <= 0 then
        vim.api.nvim_echo(
          { { "Failed to start FSI.", "ErrorMsg" } },
          false,
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

  -- Wait until FSI prompt/banner appears before first send to avoid pre-banner echo.
  local function wait_until_ready_then(fn)
    local tries, interval = 80, 75 -- ~6s max; usually much sooner
    local function ready()
      if not (fsi.buf and vim.api.nvim_buf_is_valid(fsi.buf)) then
        return false
      end
      local lc = vim.api.nvim_buf_line_count(fsi.buf)
      local start = math.max(0, lc - 50)
      local lines = vim.api.nvim_buf_get_lines(fsi.buf, start, -1, false)
      for _, L in ipairs(lines) do
        if
          L:match("^%s*>%s*$") or L:find("For help type #help;;", 1, true)
        then
          return true
        end
      end
      return false
    end
    local function poll()
      if ready() or tries <= 0 then
        pcall(fn)
      else
        tries = tries - 1
        vim.defer_fn(poll, interval)
      end
    end
    poll()
  end

  local function send_lines(lines, opts)
    opts = opts or {}
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
    log("send: bytes=%d (just_started=%s)", #payload, tostring(just_started))

    local function do_send()
      if not running() then
        log("send: job not running; abort")
        return
      end
      local ok, err = pcall(vim.fn.chansend, fsi.job, payload)
      log("send: chansend ok=%s err=%s", tostring(ok), err or "nil")
      -- If invoked from Normal mode, move cursor down one line (user request)
      if opts.move_down then
        vim.schedule(function()
          pcall(vim.cmd, "normal! j")
        end)
      end
    end

    if just_started then
      -- Wait for banner/prompt rather than fixed delay
      wait_until_ready_then(do_send)
    else
      do_send()
    end
  end

  -- ---------- Range-driven command (no Lua mark timing) ----------
  -- When invoked from Visual via ":", Neovim inserts :'<,'> automatically.
  vim.api.nvim_create_user_command("FsiSend", function(args)
    local s, e = args.line1, args.line2
    local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
    log("FsiSend: range %d..%d count=%d", s, e, #lines)

    -- Normal vs Visual: args.range==0 means no range provided → Normal-mode call.
    local move_down = (args.range == 0)
    send_lines(lines, { move_down = move_down })

    -- Keep Visual selection for repeated sends (quietly)
    if args.range and args.range > 0 then
      vim.schedule(function()
        pcall(vim.cmd, "normal! gv")
      end)
    end
  end, { range = true })

  -- Optional helpers
  vim.api.nvim_create_user_command("FsiShow", function()
    open_fsi(false)
  end, {})
  vim.api.nvim_create_user_command("FsiStatus", function()
    local msg = string.format(
      "STATUS: win=%s buf=%s job=%s running=%s sent_cd=%s log=%s",
      tostring(fsi.win),
      tostring(fsi.buf),
      tostring(fsi.job),
      tostring(running()),
      tostring(fsi.sent_cd),
      LOG_PATH
    )
    vim.api.nvim_echo({ { msg, "Comment" } }, false, {})
    log(msg)
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
        vim.api.nvim_echo({
          {
            ok and "SelfTest: PASS" or "SelfTest: FAIL",
            ok and "MoreMsg" or "ErrorMsg",
          },
        }, false, {})
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

-- LSP boot (unchanged aside from mappings)
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
      settings = {
        FSharp = {
          -- hard disable the parentheses nag
          UnnecessaryParenthesesAnalyzer = false,

          -- (optional) if you also dislike other “style nags”:
          -- SimplifyNameAnalyzer = false,
          -- UnusedOpensAnalyzer = true,
          -- UnusedDeclarationsAnalyzer = true,
          -- Linter = true, -- FSharpLint integration
        },
      },
    })

    vim.cmd("runtime! syntax/fsharp.vim")
    vim.fn.clearmatches()
    vim.fn.matchadd("fsharpOperator", "::", 150)
    vim.fn.matchadd("Operator", "::", 200)

    -- Mappings: Ex-command so Visual gets :'<,'> automatically
    local map_opts = { buffer = args.buf, desc = "F# Interactive" }
    vim.keymap.set("n", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Normal: current line (then move down)
    vim.keymap.set("x", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Visual: current selection
    vim.keymap.set("n", "<M-@>", _FSharpToggleFsi, map_opts)
  end,
})

-- ------------------------------------------------------------
-- Ensure a suitable .editorconfig for this F# project
-- Creates one at the project root if none exists up the tree.
-- :FSharpEnsureEditorConfig      -> create if missing (quiet)
-- :FSharpEnsureEditorConfig!     -> also open it
-- ------------------------------------------------------------
if not vim.g._fsharp_editorconfig_helper then
  vim.g._fsharp_editorconfig_helper = true

  -- Require your new centralized helper module
  local helpers = require("custom.fsharp_helpers")

  -- This function is unique to this file's purpose, so it stays here.
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

  vim.api.nvim_create_user_command("FSharpEnsureEditorConfig", function(args)
    -- Call the helper functions instead of defining them locally
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
  -- Optional keybinding (buffer-local): open/create and view it with <leader>fe
  -- vim.keymap.set("n", "<leader>fe", "<cmd>FSharpEnsureEditorConfig!<CR>", { buffer = 0, desc = "Ensure .editorconfig" })
end

-- Add this to the end of after/ftplugin/fsharp.lua

-- Command to easily view the string splitter's log file
vim.api.nvim_create_user_command("FSharpSplitterLog", function()
  local log_path = vim.fn.stdpath("state") .. "/fsharp_string_splitter.log"
  if vim.fn.filereadable(log_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(log_path))
  else
    vim.notify("F# Splitter log file not found.", vim.log.levels.WARN)
  end
end, { desc = "Open the F# string splitter log file" })
