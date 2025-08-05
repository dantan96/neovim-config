-- capture_report.lua - Improved capture colour report for Neovim
-- This script inspects the current buffer, reporting Tree‑sitter captures,
-- active LSP clients and whether they support semantic tokens, and the
-- current colourscheme. It resolves the highlight groups for each capture
-- (prefixed with '@') and displays the foreground/background colours and
-- the highlight group they link to. A simple `setup` function registers
-- a user command and optional key mapping for convenience.

local M = {}

-- Convert a numeric RGB value into a hex string, or return an empty
-- string when the value is nil. Neovim exposes foreground/background
-- colours as numbers.
local function hex(num)
  return num and string.format("#%06x", num) or ""
end

-- Retrieve the highlight table for a group. By passing `link = true` the
-- call follows any links defined on the group and returns the resolved
-- highlight. The returned table includes `foreground`, `background`,
-- boolean style flags and the name of the link target (when present).
-- Remove any trailing language suffix from a semantic token highlight group.
-- For example, "@lsp.type.property.lua" becomes "@lsp.type.property". If
-- there is no trailing suffix, the string is returned unchanged. This
-- helper is used to fall back to a generic semantic token when the
-- language‑specific variant is not coloured by the theme.
local function unsuffix(hl_group)
  local base, ft = hl_group:match("^(@lsp[%w%._]+)%.([%w_]+)$")
  if base and ft then
    return base
  end
  return hl_group
end

-- Collect semantic‑token highlight groups for the given buffer. Neovim
-- stores semantic tokens as extmarks in a per‑client namespace. This
-- helper extracts the `hl_group` field from each extmark’s details.
-- When semantic tokens are disabled or none have been published yet,
-- it returns an empty set. We use the private __STHighlighter table
-- to access the client namespaces. If this table is unavailable, the
-- function safely returns an empty set.
local function collect_semantic_groups(bufnr)
  local sg = {}
  local ok, st = pcall(function()
    return vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.__STHighlighter
  end)
  if ok and st and st.active then
    local highlighter = st.active[bufnr]
    if highlighter and highlighter.client_state then
      for _, state in pairs(highlighter.client_state) do
        local ns = state.namespace
        if ns then
          -- Gather extmarks in the semantic token namespace. Each extmark
          -- details table may contain an `hl_group` key corresponding to
          -- a highlight group name like '@lsp.type.variable'.
          for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
            bufnr, ns, 0, -1, { details = true })) do
            local details = mark[4]
            local hl_group = details and details.hl_group
            if hl_group then
              sg[hl_group] = true
            end
          end
        end
      end
    end
  end
  return sg
end

-- Retrieve the highlight table for a group. Follows links to resolve the
-- final colour, and falls back to a generic semantic token when a
-- language‑specific variant (e.g. "@lsp.type.variable.lua") has no
-- colour defined. The returned table includes the resolved foreground
-- and background colours (as hex strings), any style attributes and
-- the name of the highlight group ultimately used.
local function hl(group)
  -- Query the highlight group and follow links (link = true) to get the
  -- resolved colours. Newer Neovim versions return colours under the
  -- `fg`/`bg` keys; older versions still use `foreground`/`background`.
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
  if not ok or not h then
    return {}
  end
  -- Extract foreground/background colours using both new and legacy keys.
  local fg = h.fg or h.foreground
  local bg = h.bg or h.background
  local link = h.link or group
  -- If no colours are defined and this is a language‑specific semantic
  -- token ("@lsp.….<lang>"), fall back to the generic form (without
  -- the language suffix) before following any further links. This makes
  -- groups like "@lsp.type.variable.lua" inherit the colours from
  -- "@lsp.type.variable" when the theme does not define the suffix.
  if (not fg and not bg) and group:match("^@lsp") and group:match("%.[%w_]+$") then
    local base = unsuffix(group)
    -- Only attempt the fallback if we have a different base name.
    if base ~= group then
      local ok2, h2 = pcall(vim.api.nvim_get_hl, 0, { name = base, link = true })
      if ok2 and h2 then
        -- Update colours from the base group.
        fg = h2.fg or h2.foreground or fg
        bg = h2.bg or h2.background or bg
        link = h2.link or base
      end
    end
  end
  return {
    fg    = hex(fg),
    bg    = hex(bg),
    attrs = table.concat({
      h.bold      and "bold"      or nil,
      h.italic    and "italic"    or nil,
      h.underline and "underline" or nil,
    }, " "),
    link  = link,
  }
end

-- Given a set of capture names (as keys in a table), build a list of
-- rows. Each row holds the capture name, foreground colour, background
-- colour, any style attributes and the resolved highlight group. The
-- list starts with a header row to simplify formatting later on.
local function build_rows(captures)
  -- Construct a list of rows from the capture set. The first row is a
  -- header describing the columns. Subsequent rows contain the capture
  -- name, its resolved foreground/background colours, any style flags
  -- and the highlight group to which it ultimately links. Capture
  -- names that already begin with '@' are left untouched; others are
  -- prefixed with '@' before looking up highlights. This supports both
  -- Tree‑sitter captures (e.g. 'keyword') and semantic tokens (e.g.
  -- '@lsp.type.function').
  local rows = { { "capture", "fg", "bg", "attrs", "link" } }
  captures = captures or {}
  for cap in pairs(captures) do
    -- Prefix non‑semantic capture names with '@'. Semantic token
    -- names already include the leading '@'.
    local group = cap:match("^@") and cap or ("@" .. cap)
    local hinfo = hl(group)
    rows[#rows + 1] = { cap, hinfo.fg, hinfo.bg, hinfo.attrs, hinfo.link }
  end
  return rows
end

-- Main entry point. This function collects data about the current buffer
-- and constructs a scratch buffer to display the report.
function M.run()
  local buf = vim.api.nvim_get_current_buf()

  -- Determine the active Tree‑sitter language for this buffer, if any.
  local lang = (function()
    local ok, p = pcall(vim.treesitter.get_parser, buf)
    return ok and p and p:lang() or nil
  end)()

  -- Collect information about attached LSP clients and whether they
  -- provide semantic tokens. Use the modern `vim.lsp.get_clients` API
  -- introduced in Neovim 0.11. The `bufnr` filter restricts to the
  -- current buffer.
  local lsp_lines = {}
  for _, client in pairs(vim.lsp.get_clients({ bufnr = buf })) do
    local tok = client.server_capabilities
                 and client.server_capabilities.semanticTokensProvider
                 and "✔" or "✘"
    table.insert(lsp_lines,
      string.format("• %s  (semantic-tokens %s)", client.name, tok))
  end
  if #lsp_lines == 0 then
    lsp_lines[1] = "∅  (no LSP)"
  end

  -- Determine the active colourscheme name. When no colourscheme is
  -- loaded, `vim.g.colors_name` is nil.
  local scheme = vim.g.colors_name or "NONE"

  -- Collect capture names from the language’s highlights query. We build
  -- a set where keys are capture names and values are true. If no
  -- parser or highlights query exists, `caps` remains empty.
  local caps = {}
  if lang then
    local q = vim.treesitter.query.get(lang, "highlights")
    if q then
      for _, name in pairs(q.captures or {}) do
        caps[name] = true
      end
    end
  end

  -- Merge in highlight groups used by LSP semantic tokens. First use
  -- the extmark approach to gather highlight group names currently
  -- present in the buffer. Keep the exact name and also add the
  -- generic form (without the trailing language suffix) for each.
  do
    for hl_group in pairs(collect_semantic_groups(buf)) do
      caps[hl_group] = true
      local generic = hl_group:gsub("%.[%w_]+$", "")
      if generic ~= hl_group then
        caps[generic] = true
      end
    end
  end

  -- Fallback: if no semantic tokens have been published yet, `collect_semantic_groups`
  -- may return an empty set. To ensure we still report semantic token
  -- highlight groups, enumerate all highlight groups that start with
  -- '@lsp' via the built‑in completion API. For each, also add its
  -- generic form.
  do
    local ok, completions = pcall(function()
      return vim.fn.getcompletion("@lsp", "highlight")
    end)
    if ok and type(completions) == "table" then
      for _, name in ipairs(completions) do
        caps[name] = true
        local generic = name:gsub("%.[%w_]+$", "")
        if generic ~= name then
          caps[generic] = true
        end
      end
    end
  end

  -- Build rows for each capture. This uses the helper to resolve
  -- highlight colours and handle missing data gracefully.
  local rows = build_rows(caps)
  -- Sort rows (except header) alphabetically by capture name for easier reading.
  do
    local header = rows[1]
    table.remove(rows, 1)
    table.sort(rows, function(a, b)
      return a[1] < b[1]
    end)
    table.insert(rows, 1, header)
  end

  -- Create a scratch buffer to display the report. Using a new buffer
  -- avoids altering the user’s files. We mark it unmodifiable to
  -- prevent accidental edits.
  local out = vim.api.nvim_create_buf(false, true)
  local function add(line)
    vim.api.nvim_buf_set_lines(out, -1, -1, false, { line })
  end

  add("┏ Capture‑colour report ┓")
  add(("Tree‑sitter parser : %s"):format(lang or "none"))
  add(("Colourscheme       : %s"):format(scheme))
  add("LSP clients        :")
  for _, l in ipairs(lsp_lines) do
    add("  " .. l)
  end
  add("")
  add(string.format("%-30s %-9s %-9s %-12s %s", unpack(rows[1])))
  for i = 2, #rows do
    add(string.format("%-30s %-9s %-9s %-12s %s", unpack(rows[i])))
  end

  vim.bo[out].modifiable = false
  vim.bo[out].filetype = "capture_report"
  vim.api.nvim_set_current_buf(out)
end

-- Set up the module. Registers a user command and, optionally, a
-- key mapping. The command defaults to `CaptureReport` and the mapping
-- can be provided in the options table.
function M.setup(opts)
  opts = opts or {}
  local cmd = opts.command or "CaptureReport"
  local key = opts.keymap
  vim.api.nvim_create_user_command(cmd, M.run, { desc = "Show capture colours" })
  if key then
    vim.keymap.set("n", key, M.run, {
      desc = "Capture‑colour report",
      noremap = true,
      silent = true,
    })
  end
end

return M