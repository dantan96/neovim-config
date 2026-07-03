-- lua/custom/fsharp_helpers.lua

local M = {}

-- =============================================================================
--  DEBUGGING INFRASTRUCTURE
-- =============================================================================
-- Off by default; set vim.g.fsharp_splitter_debug = true (or flip this
-- check) when diagnosing :FSharpSplitStrings.
local DEBUG = vim.g.fsharp_splitter_debug == true
local LOG_PATH = vim.fn.stdpath("state") .. "/fsharp_string_splitter.log"

-- A more robust logger using vim.fn.writefile, like your FSI logger.
local function log(msg, ...)
  if not DEBUG then
    return
  end
  -- Overwrite the log on the first write of a new run.
  local mode = M._log_started and "a" or "w"
  M._log_started = true

  local s = string.format(msg, ...)
  pcall(
    vim.fn.writefile,
    { string.format("[%s] %s", os.date("!%T"), s) },
    LOG_PATH,
    mode
  )
end

-- =============================================================================
--  HELPER FUNCTIONS (Unchanged)
-- =============================================================================

function M.project_root()
  local fname = vim.api.nvim_buf_get_name(0)
  local ok, util = pcall(require, "lspconfig.util")
  if ok then
    return util.root_pattern("*.sln", "*.fsproj", ".git")(fname)
      or vim.fs.dirname(fname)
  else
    return vim.fs.dirname(fname)
  end
end

function M.find_editorconfig(start_dir)
  local found = vim.fs.find(
    ".editorconfig",
    { upward = true, path = start_dir, type = "file" }
  )
  return (#found > 0) and found[1] or nil
end

-- Single fallback width, matching the max_line_length that
-- :FSharpEnsureEditorConfig writes into a fresh .editorconfig.
local DEFAULT_MAX_LINE_LENGTH = 79

function M.get_max_line_length()
  local root = M.project_root()
  if not root then
    return DEFAULT_MAX_LINE_LENGTH
  end
  local editorconfig_path = M.find_editorconfig(root)
  if not editorconfig_path then
    return DEFAULT_MAX_LINE_LENGTH
  end
  local lines = vim.fn.readfile(editorconfig_path)
  for _, line in ipairs(lines) do
    local len = string.match(line, "^%s*max_line_length%s*=%s*(%d+)")
    if len then
      return tonumber(len)
    end
  end
  return DEFAULT_MAX_LINE_LENGTH
end

-- =============================================================================
--  CORE SPLITTING LOGIC (balanced, interpolation-safe, no regex pitfalls)
-- =============================================================================

-- 1) Parse prefix sigil(s) and delimiter literally (no Lua-regex).
--    Accepts: $"...", $@"...", @$"...", @"...", "..." and their """ variants.
local function parse_prefix_and_delim(full)
  local i, n = 1, #full
  local sigil = ""
  while i <= n do
    local c = full:sub(i, i)
    if c == "$" or c == "@" then
      sigil = sigil .. c
      i = i + 1
    else
      break
    end
  end
  local delim
  if full:sub(i, i + 2) == '"""' then
    delim = '"""'
    i = i + 3
  elseif full:sub(i, i) == '"' then
    delim = '"'
    i = i + 1
  else
    -- not a string literal we handle
    return "", "", nil, nil
  end
  -- compute content span
  local content_start = i
  local content_end = n - #delim
  if content_end < content_start then
    return "", "", nil, nil
  end
  return sigil, delim, content_start, content_end
end

M._parse_prefix_and_delim = parse_prefix_and_delim

-- 2) Collect “safe” breakpoints in `raw` outside any { ... } placeholder.
--    We track depth only when the string is interpolated (has '$').
local NICE_TOKENS =
  { " and ", ", ", "; ", " - ", " + ", " or ", " then ", " else " }
local function collect_safe_breaks(raw, interpolated)
  local breaks = {}
  local i, n, depth = 1, #raw, 0
  while i <= n do
    if interpolated then
      local two = raw:sub(i, i + 1)
      if two == "{{" or two == "}}" then
        i = i + 2
        goto continue
      end
      local ch = raw:sub(i, i)
      if ch == "{" then
        depth = depth + 1
        i = i + 1
        goto continue
      end
      if ch == "}" then
        depth = math.max(0, depth - 1)
        i = i + 1
        goto continue
      end
    end
    if depth == 0 then
      for _, tok in ipairs(NICE_TOKENS) do
        if raw:sub(i, i + #tok - 1) == tok then
          -- Save the *start* of the token so the token goes with the RIGHT piece
          table.insert(breaks, { start = i, tok = tok })
        end
      end
    end
    ::continue::
    i = i + 1
  end
  -- fallback: spaces near boundaries
  if #breaks == 0 then
    local j = 1
    while true do
      local k = raw:find(" ", j, true)
      if not k then
        break
      end
      table.insert(breaks, { start = k, tok = " " })
      j = k + 1
    end
  end
  return breaks
end

M._collect_safe_breaks = collect_safe_breaks

-- 3) Choose a split close to the target column, but never inside { ... }.
local function pick_balanced_break(breaks, target_col)
  local best, bestdist = nil, math.huge
  for _, b in ipairs(breaks) do
    local d = math.abs(b.start - target_col)
    if d < bestdist then
      best, bestdist = b, d
    end
  end
  return best
end

M._pick_balanced_break = pick_balanced_break

-- 4) Recursively split into pieces that fit `eff_width`, keeping tokens readable.
local function split_outside_interpolation(raw, eff_width, interpolated, depth)
  depth = (depth or 0) + 1
  if #raw <= eff_width or depth > 8 then
    return { raw }
  end
  local breaks = collect_safe_breaks(raw, interpolated)
  if #breaks == 0 then
    return { raw }
  end
  local target = math.floor(#raw / 2)
  local br = pick_balanced_break(breaks, target)
  if not br then
    return { raw }
  end

  -- Put the token at the start of the RIGHT piece
  local left = raw:sub(1, br.start - 1)
  local right = raw:sub(br.start)

  -- If we split on a plain space, keep exactly one space on the right.
  if br.tok == " " then
    -- remove trailing spaces from left, ensure single leading space on right
    left = left:gsub("%s+$", "")
    right = right:gsub("^%s+", " ")
  end

  local out = {}
  for _, piece in ipairs({ left, right }) do
    if #piece > eff_width then
      local more =
        split_outside_interpolation(piece, eff_width, interpolated, depth)
      for _, m in ipairs(more) do
        table.insert(out, m)
      end
    else
      table.insert(out, piece)
    end
  end
  return out
end

function M.split_long_strings_in_buffer(bufnr)
  -- Reset log
  M._log_started = false
  log("Starting string splitter run for buffer: %d", bufnr)

  local max_len = M.get_max_line_length()
  log("Using max_line_length: %d", max_len)

  -- nvim-treesitter's parsers.get_parser was removed on the `main` branch;
  -- use the core API instead.
  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, "fsharp")
  if not parser_ok or not parser then
    log("ERROR: F# Tree-sitter parser not available.")
    return nil
  end
  log("Tree-sitter parser loaded successfully.")

  local tree = parser:parse()[1]
  if not tree then
    log("ERROR: Failed to parse buffer into a syntax tree.")
    return nil
  end
  local root = tree:root()

  local query = vim.treesitter.query.parse("fsharp", "[(string) @string]")
  if not query then
    log("ERROR: Failed to parse Tree-sitter query.")
    return nil
  end

  local changes = {}
  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local node_text = vim.treesitter.get_node_text(node, bufnr) or ""
    local srow, scol, erow, ecol = node:range()
    log("\nFound node: %q at [%d:%d]", node_text, srow, scol)

    -- Parse sigil and delimiter *safely*
    local sigil, delim, cs, ce = parse_prefix_and_delim(node_text)
    if not cs then
      log(" -> Unrecognized literal form; skipping.")
      goto continue
    end
    -- We’re conservative: only split single-line strings for now
    if srow ~= erow then
      log(" -> Multiline node; skipping.")
      goto continue
    end

    local raw = node_text:sub(cs, ce)
    -- Effective width inside one literal (account for sigil + quotes)
    local eff = math.max(20, max_len - #sigil - (#delim * 2))
    if #raw <= eff then
      log(" -> Fits eff_width=%d; skipping.", eff)
      goto continue
    end

    local interpolated = sigil:find("%$")
    log(
      " -> Over eff_width=%d; splitting (interpolated=%s)...",
      eff,
      interpolated and "yes" or "no"
    )

    local parts = split_outside_interpolation(raw, eff, interpolated ~= nil)
    if #parts > 1 then
      local out = {}
      for i, p in ipairs(parts) do
        -- Keep original sigil and delimiter on every piece
        local piece = sigil .. delim .. p .. delim
        out[#out + 1] = piece
        log("    -> Part %d: %s", i, piece)
      end
      local replacement = table.concat(out, " + ")
      table.insert(changes, {
        start_row = srow,
        start_col = scol,
        end_row = erow,
        end_col = ecol,
        text = replacement,
      })
      log(" -> Replacement ready.")
    else
      log(" -> Only one part; skipping.")
    end

    ::continue::
  end

  if #changes == 0 then
    log("No changes to apply. Finishing run.")
    return nil
  end

  log("\nApplying %d changes to the buffer...", #changes)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  table.sort(changes, function(a, b)
    return a.start_row > b.start_row
      or (a.start_row == b.start_row and a.start_col > b.start_col)
  end)
  for _, ch in ipairs(changes) do
    local old = lines[ch.start_row + 1]
    lines[ch.start_row + 1] = old:sub(1, ch.start_col)
      .. ch.text
      .. old:sub(ch.end_col + 1)
    log(" -> Applied change at row %d", ch.start_row + 1)
  end
  log("Finished applying changes.")
  return lines
end

return M
