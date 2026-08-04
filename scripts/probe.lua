-- probe.lua — dumps the runtime facts that static reading cannot confirm.
-- Driven by scripts/probe.sh (which sets vim.g.__probe_out/_line/_col).
--
-- Waits for LSP attach and treesitter before sampling, because semantic tokens
-- and highlight extmarks arrive asynchronously; sampling immediately after
-- `edit` reports "nothing attached" on a config that is in fact fine.

local out_path = vim.g.__probe_out
local line = tonumber(vim.g.__probe_line) or 1
local col = tonumber(vim.g.__probe_col) or 1

local function finish(tbl, code)
  local ok, encoded = pcall(vim.json.encode, tbl)
  if not ok then
    encoded = vim.json.encode({ error = "encode failed: " .. tostring(encoded) })
  end
  if out_path then
    local fh = io.open(out_path, "w")
    if fh then
      fh:write(encoded)
      fh:close()
    end
  end
  -- cquit, not error(): a headless `-c 'lua error(...)'` exits 0.
  vim.cmd("cquit " .. tostring(code or 0))
end

local ok, result = pcall(function()
  local buf = vim.api.nvim_get_current_buf()

  -- Let lazy finish, LSP attach, and treesitter parse. Bounded, not blind sleep.
  vim.wait(10000, function()
    return pcall(require, "lazy")
  end)
  vim.wait(8000, function()
    return #vim.lsp.get_clients({ bufnr = buf }) > 0
  end)
  vim.wait(3000, function()
    local okp, parser = pcall(vim.treesitter.get_parser, buf)
    return okp and parser ~= nil
  end)
  vim.wait(1500) -- semantic tokens land after attach

  local nlines = vim.api.nvim_buf_line_count(buf)
  line = math.max(1, math.min(line, nlines))
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  col = math.max(1, math.min(col, math.max(#text, 1)))

  local data = {
    file = vim.api.nvim_buf_get_name(buf),
    filetype = vim.bo[buf].filetype,
    line = line,
    col = col,
    line_text = text,
    lines_total = nlines,
  }

  -- Treesitter captures at position (0-indexed row/col)
  local okc, captures = pcall(vim.treesitter.get_captures_at_pos, buf, line - 1, col - 1)
  data.treesitter_captures = okc and captures or { error = tostring(captures) }

  -- Full highlight resolution: treesitter + semantic tokens + syntax + extmarks
  local oki, inspected = pcall(vim.inspect_pos, buf, line - 1, col - 1)
  if oki then
    data.inspect_pos = {
      treesitter = inspected.treesitter,
      semantic_tokens = inspected.semantic_tokens,
      syntax = inspected.syntax,
      extmarks = inspected.extmarks,
    }
  else
    data.inspect_pos = { error = tostring(inspected) }
  end

  -- Resolved highlight groups actually in effect at that position
  local groups = {}
  if okc and type(captures) == "table" then
    for _, cap in ipairs(captures) do
      local name = "@" .. cap.capture
      local okh, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
      groups[name] = okh and hl or nil
    end
  end
  data.resolved_highlights = groups

  -- LSP clients + the capability bits that usually explain "why no X"
  local clients = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    local sc = c.server_capabilities or {}
    clients[#clients + 1] = {
      name = c.name,
      id = c.id,
      root_dir = c.config and c.config.root_dir or nil,
      semantic_tokens = sc.semanticTokensProvider ~= nil,
      hover = sc.hoverProvider ~= nil,
      definition = sc.definitionProvider ~= nil,
      formatting = sc.documentFormattingProvider ~= nil,
    }
  end
  data.lsp_clients = clients

  data.diagnostics = vim.diagnostic.get(buf)

  -- conform/none-ls formatters, since "why didn't it format" is a recurring one
  local okf, conform = pcall(require, "conform")
  if okf and conform.list_formatters then
    local names = {}
    for _, f in ipairs(conform.list_formatters(buf) or {}) do
      names[#names + 1] = { name = f.name, available = f.available }
    end
    data.conform_formatters = names
  end

  return data
end)

if ok then
  finish(result, 0)
else
  finish({ error = tostring(result) }, 1)
end
