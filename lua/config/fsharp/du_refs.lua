-- lua/config/fsharp/du_refs.lua
-- Paint every reference of a DU-case binder (`| Case binder -> ...`) in
-- the enum-member color. Session-global machinery: one LspTokenUpdate
-- handler plus per-buffer extmark bookkeeping, created exactly once.

local M = {}

local ts = vim.treesitter

local done = false

function M.setup()
  if done then
    return
  end
  done = true

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
end

return M
