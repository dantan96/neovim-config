-- luacheck: globals vim _FSharpToggleFsi
-- Indentation for F#
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4
vim.opt_local.autoindent = false
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

local cp = require("catppuccin.palettes").get_palette("mocha")
local sky = cp.sky

-- UI tweaks (yours)
vim.api.nvim_set_hl(
  0,
  "@variable.parameter.fsharp",
  { fg = "#f38ba8", bold = false, underline = false }
)
vim.api.nvim_set_hl(0, "@enum.member.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@lsp.type.enumMember.fsharp", { fg = "#ff69b4" })
vim.api.nvim_set_hl(0, "@operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(0, "@lsp.type.operator.fsharp", { fg = "#94e2d5" })
vim.api.nvim_set_hl(
  0,
  "@lsp.type.type.fsharp",
  { fg = "#f9e2af", underline = false, bold = false }
)
vim.api.nvim_set_hl(
  0,
  "@type.fsharp",
  { fg = "#f9e2af", underline = false, bold = false }
)
local limegreen = { fg = "#aaff00", italic = true, bold = true }
local electriccyan = { fg = "#00ffff", italic = true }
local deepteal = { fg = "#008080", italic = true }
local deepteal2 = { fg = "#00cccc", italic = true }
local brightmagenta = { fg = "#ff00ff", italic = true }
local brightmagentabold = { fg = "#ff00ff", italic = true, bold = true }
local GOLD = "#FFD700" -- CSS 'gold'
local AMBER500 = "#FFC107" -- Material Amber 500
local GOLDENROD = "#DAA520" -- CSS 'goldenrod'
local g1 = { fg = GOLD, italic = true }
local g2 = { fg = AMBER500, italic = true }
local g3 = { fg = GOLDENROD, italic = true }
-- Retrieve the sky color from Catppuccin palette
vim.api.nvim_set_hl(0, "@lsp.type.typeParameter.fsharp", g1)

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
  { fg = "#f9e2af", italic = true, underline = true }
)

vim.api.nvim_set_hl(
  0,
  "@lsp.typemod.property.readonly",
  { fg = "#fab387", italic = true }
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
  { fg = "#f5c2e7", underline = false }
)
vim.api.nvim_set_hl(
  0,
  "@punctuation.special",
  { fg = "#9399b2", underline = false }
)

---------------------------------------------------------------------------
-- ==========  BEEFING UP SEMANTIC COLOURING  ==========
---------------------------------------------------------------------------
local function link_binder_hl()
  vim.api.nvim_set_hl(
    0,
    "@lsp.variable.enum_member.fsharp",
    { link = "@variable.enum_member.fsharp", default = false }
  )
end

link_binder_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("fs_du_binder_hl", { clear = true }),
  callback = link_binder_hl,
})

local ts = vim.treesitter

-- The DU-binder reference machinery below is session-global (an
-- LspTokenUpdate handler plus its extmark bookkeeping). Create it exactly
-- once: this ftplugin is re-sourced for every F# buffer, and re-creating
-- the state while clearing the augroup left stale extmark bookkeeping for
-- other buffers and re-registered the handler each time.
if not vim.g._fsharp_du_refs_setup then
  vim.g._fsharp_du_refs_setup = true

  local ns_refs = vim.api.nvim_create_namespace("fs_du_binder_refs")

  -- Per-buffer state so multiple binders don't clear each other
  local _du_state = {}
  local function _bufstate(bufnr)
    local s = _du_state[bufnr]
    if not s then
      s = { marks = {}, gen = {}, tick = {} }
      _du_state[bufnr] = s
    end
    return s
  end

  -- Free a buffer's bookkeeping when the buffer goes away
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup(
      "fs_du_binder_state_gc",
      { clear = true }
    ),
    callback = function(args)
      _du_state[args.buf] = nil
    end,
  })

  -- Rightmost identifier under a node (handles Type.Case)
  local function rightmost_ident(node)
    local last
    local function walk(n)
      if n:type() == "identifier" then
        last = n
      end
      for c in n:iter_children() do
        walk(c)
      end
    end
    walk(node)
    return last
  end

  -- Is this token a binder in `Case binder`? If yes, return the CASE coords.
  local function case_coords_for_binder(buf, row, col)
    local node =
      ts.get_node({ bufnr = buf, pos = { row, col }, ignore_injections = true })
    if not node then
      local p = ts.get_parser(buf)
      if p then
        p:parse()
      end
      node = ts.get_node({
        bufnr = buf,
        pos = { row, col },
        ignore_injections = true,
      })
    end
    while node do
      if node:type() == "identifier_pattern" then
        local kids = {}
        for c in node:iter_children() do
          table.insert(kids, c)
        end
        if #kids >= 2 and kids[1]:type() == "long_identifier_or_op" then
          local id = rightmost_ident(kids[1])
          if id then
            local r, c0 = id:start()
            return r, c0
          end
        end
      end
      node = node:parent()
    end
  end

  -- Convert between LSP Positions and byte columns using the client's actual
  -- offset encoding, via the Neovim 0.11+ signatures:
  --   vim.str_byteindex(s, encoding, index, strict_indexing)
  --   vim.str_utfindex(s, encoding, index, strict_indexing)
  -- (The old numeric use_utf16 third argument is deprecated; worse, `0` is
  -- truthy in Lua, so the previous code always took the utf-16 branch.)

  -- LSP character -> byte column (for extmarks)
  local function lsp_pos_to_bytes(bufnr, pos, enc)
    local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, true)[1]
      or ""
    -- strict_indexing=false clamps out-of-range positions to the line end.
    return pos.line, vim.str_byteindex(line, enc or "utf-16", pos.character, false)
  end

  -- Buffer byte column -> LSP character
  local function lsp_char_from_byte(bufnr, line_nr, bytecol, enc)
    local line = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, true)[1]
      or ""
    return vim.str_utfindex(line, enc or "utf-16", bytecol, false)
  end

  -- Highlight all references in the current buffer for ONE binder key
  local function paint_refs_for_pos(bufnr, client, pos_byte, key)
    local base = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local params = {
      textDocument = base.textDocument,
      position = {
        line = pos_byte.line,

        character = lsp_char_from_byte(
          bufnr,
          pos_byte.line,
          pos_byte.byte,
          client.offset_encoding
        ),
      },
      context = { includeDeclaration = true },
    }

    local s = _bufstate(bufnr)

    -- Generation token per binder; ignore stale callbacks (no req_id tracking)
    s.gen[key] = (s.gen[key] or 0) + 1
    local gen = s.gen[key]

    client:request("textDocument/references", params, function(err, result, _)
      if gen ~= s.gen[key] then
        return
      end
      if err or not result then
        return
      end

      -- Clear ONLY this binder's previous marks
      if s.marks[key] then
        for _, id in ipairs(s.marks[key]) do
          pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_refs, id)
        end
      end
      s.marks[key] = {}

      for _, loc in ipairs(result) do
        if vim.uri_to_bufnr(loc.uri) == bufnr then
          local sL, sB =
            lsp_pos_to_bytes(bufnr, loc.range.start, client.offset_encoding)
          local eL, eB =
            lsp_pos_to_bytes(bufnr, loc.range["end"], client.offset_encoding)
          local id = vim.api.nvim_buf_set_extmark(bufnr, ns_refs, sL, sB, {
            end_row = eL,
            end_col = eB,
            hl_group = "@variable.enum_member.fsharp",
            hl_mode = "combine",
            priority = vim.hl.priorities.semantic_tokens + 3,
          })
          table.insert(s.marks[key], id)
        end
      end
    end, bufnr)
  end

  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = vim.api.nvim_create_augroup("fs_du_binder_refs", { clear = true }),
    callback = function(args)
      if vim.bo[args.buf].filetype ~= "fsharp" then
        return
      end
      local tok = args.data.token
      if tok.type ~= "variable" and tok.type ~= "parameter" then
        return
      end

      -- Cheap cache: LspTokenUpdate fires per token on every semantic-tokens
      -- refresh. If we already issued a references request for this binder
      -- position and the buffer hasn't changed since, skip the treesitter
      -- walk and the duplicate request. (Only successful requests are
      -- cached, below, so partial token data is re-evaluated.)
      local key = string.format("%d:%d", tok.line, tok.start_col)
      local tick = vim.api.nvim_buf_get_changedtick(args.buf)
      if _bufstate(args.buf).tick[key] == tick then
        return
      end

      -- 1) Structurally: are we a binder after a case?
      local case_r, case_c =
        case_coords_for_binder(args.buf, tok.line, tok.start_col)
      if not case_r then
        return
      end

      -- 2) Semantically: is that preceding node actually an enumMember?
      local case_tokens =
        vim.lsp.semantic_tokens.get_at_pos(args.buf, case_r, case_c)
      local ok = false
      for _, t in ipairs(case_tokens or {}) do
        if t.client_id == args.data.client_id and t.type == "enumMember" then
          ok = true
          break
        end
      end
      if not ok then
        return
      end

      -- 3) Fetch ALL references for this binder and paint them (without nuking others)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end

      _bufstate(args.buf).tick[key] = tick
      paint_refs_for_pos(
        args.buf,
        client,
        { line = tok.line, byte = tok.start_col },
        key
      )
    end,
  })

end -- vim.g._fsharp_du_refs_setup once-guard

-- -- Optional: if you want to refresh on edits, uncomment this (not required)
-- vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
--   group = vim.api.nvim_create_augroup("fs_du_binder_refs_refresh", { clear = true }),
--   callback = function() vim.lsp.semantic_tokens.force_refresh(0) end,
-- })

---------------------------------------------------------------------------
-- ==========  END OF BEEFING UP SEMANTIC COLOURING  ==========
---------------------------------------------------------------------------
-- === Constraint name overlay inside (constraint) nodes ======================
local ns_constraints = vim.api.nvim_create_namespace("fs_constraint_names")

-- Words to light up inside constraint nodes (word-boundary safe).
local CONSTRAINT_PATTERNS = {
  "%f[%w_]comparison%f[^%w_]",
  "%f[%w_]equality%f[^%w_]",
  "%f[%w_]struct%f[^%w_]",
  "%f[%w_]unmanaged%f[^%w_]",
  "%f[%w_]enum%f[^%w_]",
  "%f[%w_]delegate%f[^%w_]",
  -- two-word form:
  "%f[%w_]not%f[^%w_]%s+%f[%w_]struct%f[^%w_]",
}

-- Treesitter query to grab constraint nodes. pcall'd: if the fsharp parser
-- is not (yet) registered — e.g. nvim-treesitter has not been loaded by
-- lazy.nvim at the time this ftplugin is sourced — degrade to "no
-- constraint overlay" instead of aborting the whole ftplugin.
local constraint_query_ok, constraint_query = pcall(
  ts.query.parse,
  "fsharp",
  [[
  (constraint) @c
]]
)
if not constraint_query_ok then
  constraint_query = nil
end

-- === extmark highlighter (replacement for deprecated add_highlight) =========
local function hl_add(buf, lnum, start_col, end_col)
  vim.api.nvim_buf_set_extmark(buf, ns_constraints, lnum, start_col, {
    end_row = lnum,
    end_col = end_col,
    hl_group = "FsharpConstraint",
    priority = 130,
  })
end

local function find_all_ranges(line, col_start, col_end)
  local sub = line:sub(col_start + 1, col_end)
  local out = {}
  for _, patt in ipairs(CONSTRAINT_PATTERNS) do
    local idx = 1
    while true do
      local a, b = sub:find(patt, idx)
      if not a then
        break
      end
      table.insert(out, { col_start + a - 1, col_start + b }) -- [start, end)
      idx = b + 1
    end
  end
  return out
end

-- Use iter_captures() so we always get a TSNode, never a table/nil
local function refresh_constraint_names(buf)
  if not constraint_query then
    return
  end
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "fsharp" then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns_constraints, 0, -1)

  local parser_ok, parser = pcall(ts.get_parser, buf, "fsharp")
  if not parser_ok or not parser then
    return
  end

  local trees = parser:parse()
  if not trees or #trees == 0 then
    return
  end

  for _, tree in ipairs(trees) do
    local root = tree:root()

    -- NB: iter_captures returns (capture_id, node, metadata)
    for _, node, _ in constraint_query:iter_captures(root, buf, 0, -1) do
      -- At this point `node` is a TSNode (has :range()).
      local srow, scol, erow, ecol = node:range()

      for lnum = srow, erow do
        local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1]
          or ""
        local from = (lnum == srow) and scol or 0
        local to = (lnum == erow) and ecol or #line

        for _, r in ipairs(find_all_ranges(line, from, to)) do
          hl_add(buf, lnum, r[1], r[2])
        end
      end
    end
  end
end

-- Refresh on typical edit/parse events (cheap enough; only scans constraint nodes)
-- Refresh on typical edit/parse events (deferred to avoid fast-event yields)
vim.api.nvim_create_autocmd(
  { "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" },
  {
    group = vim.api.nvim_create_augroup(
      "fs_constraint_names_refresh",
      { clear = true }
    ),
    pattern = { "*.fs", "*.fsx", "*.fsi" },
    callback = function(args)
      -- Defer out of Treesitter’s fast C-callback to prevent “yield across C-call boundary”
      vim.schedule(function()
        pcall(refresh_constraint_names, args.buf)
      end)
    end,
  }
)

-- Also refresh after colorscheme (so highlight group exists) and after
-- writes. These need separate autocmds: ColorScheme matches the colorscheme
-- NAME while BufWritePost matches file PATHS, so a single autocmd with
-- pattern "catppuccin" meant the write-refresh never fired.
local constraint_colors_group =
  vim.api.nvim_create_augroup("fs_constraint_names_colors", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = constraint_colors_group,
  pattern = "catppuccin",
  callback = function()
    refresh_constraint_names(0)
  end,
})
vim.api.nvim_create_autocmd("BufWritePost", {
  group = constraint_colors_group,
  pattern = { "*.fs", "*.fsx", "*.fsi" },
  callback = function(args)
    refresh_constraint_names(args.buf)
  end,
})

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

-- LSP boot. This ftplugin is itself sourced on FileType for every F#
-- buffer, so run the boot logic directly instead of registering a nested
-- FileType autocmd (which never fired for the first F# buffer of a session
-- and duplicated itself on every subsequent one).
do
  local bufnr = vim.api.nvim_get_current_buf()

  -- Don’t start a second client if one is already active for this buffer
  local already_attached = false
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == "fsautocomplete" then
      already_attached = true
      break
    end
  end

  if not already_attached then
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local util = require("lspconfig.util")
    -- vim.lsp.start also dedups per (name, root_dir): a second buffer in
    -- the same root reuses the running client instead of starting another.
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
    -- Remove only OUR previous matches in this window (clearmatches() would
    -- also nuke matches added by other plugins), then re-add and re-track.
    for _, id in ipairs(vim.w.fsharp_match_ids or {}) do
      pcall(vim.fn.matchdelete, id)
    end
    vim.w.fsharp_match_ids = {
      vim.fn.matchadd("fsharpOperator", "::", 150),
      vim.fn.matchadd("Operator", "::", 200),
    }

    -- Mappings: Ex-command so Visual gets :'<,'> automatically
    local map_opts = { buffer = bufnr, desc = "F# Interactive" }
    vim.keymap.set("n", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Normal: current line (then move down)
    vim.keymap.set("x", "<M-CR>", [[:FsiSend<CR>]], map_opts) -- Visual: current selection
    vim.keymap.set("n", "<M-@>", _FSharpToggleFsi, map_opts)
  end
end

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
--
-- gold toggles for FsharpConstraint

local function set_constraint(hex)
  vim.api.nvim_set_hl(0, "FsharpConstraint", {
    fg = hex,
    italic = true,
    bold = false, -- keep crisp; turn on if you want extra punch
    nocombine = true,
  })
  pcall(refresh_constraint_names, 0)
end

local BRIGHTMAGENTA = "#ff00ff"
set_constraint(BRIGHTMAGENTA)
-- vim.keymap.set("n", "<leader>fg", function()
--   set_constraint_gold(BRIGHTMAGENTA)
-- end, { desc = "Constraint → bright gold" })
-- vim.keymap.set("n", "<leader>fa", function()
--   set_constraint_gold(AMBER500)
-- end, { desc = "Constraint → amber 500" })
-- vim.keymap.set("n", "<leader>fr", function()
--   set_constraint_gold(GOLDENROD)
-- end, { desc = "Constraint → goldenrod (deeper)" })

-- Buffer-local command to split long string literals so they fit within
-- the project's max_line_length (see custom.fsharp_helpers).
vim.api.nvim_buf_create_user_command(0, "FSharpSplitStrings", function()
  local helpers = require("custom.fsharp_helpers")
  local bufnr = vim.api.nvim_get_current_buf()
  local new_lines = helpers.split_long_strings_in_buffer(bufnr)
  if new_lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
    vim.notify("FSharp: long strings split.", vim.log.levels.INFO)
  else
    vim.notify("FSharp: no strings needed splitting.", vim.log.levels.INFO)
  end
end, { desc = "Split long F# string literals to fit max_line_length" })

-- Command to easily view the string splitter's log file
vim.api.nvim_create_user_command("FSharpSplitterLog", function()
  local log_path = vim.fn.stdpath("state") .. "/fsharp_string_splitter.log"
  if vim.fn.filereadable(log_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(log_path))
  else
    vim.notify("F# Splitter log file not found.", vim.log.levels.WARN)
  end
end, { desc = "Open the F# string splitter log file" })
