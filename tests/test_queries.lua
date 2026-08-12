-- tests/test_queries.lua — treesitter query resolution and F# rendering.
--
-- Guards against two real bugs found in review:
--  * a config query file silently DROPPED by vim.treesitter.query.get_files
--    (a non-extends file after the base is discarded, so a missing
--    ";; extends" modeline turns the whole file into a no-op), and
--  * the cons operator "::" losing its custom capture in match-pattern
--    position (cons_pattern) while keeping it in expression position.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["queries"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

-- Every query file shipped in this config must survive runtime
-- resolution: it must appear in get_files() for its (lang, query) pair.
-- This is the systematic invariant; it fails if a future query file
-- forgets ";; extends" while a plugin/base query exists for the lang.
local config_query_files = {}
for _, dir in ipairs({ "queries", "after/queries" }) do
  local base = vim.fn.stdpath("config") .. "/" .. dir
  for _, path in ipairs(vim.fn.glob(base .. "/*/*.scm", false, true)) do
    local lang = vim.fn.fnamemodify(path, ":h:t")
    local query = vim.fn.fnamemodify(path, ":t:r")
    table.insert(config_query_files, { lang, query, path })
  end
end

T["queries"]["glob found the query files"] = function()
  -- Guard against vacuous parametrization: if the collection-time glob
  -- returns nothing (path rename, wrong cwd), zero cases would be
  -- generated and the set would pass silently.
  expect.equality(#config_query_files >= 3, true)
end

T["queries"]["config query files resolve"] = new_set({
  parametrize = config_query_files,
}, {
  test = function(lang, query, path)
    local resolved = child.lua_get(
      string.format(
        [[vim.treesitter.query.get_files(%q, %q)]],
        lang,
        query
      )
    )
    local found = false
    for _, f in ipairs(resolved) do
      if f == path then
        found = true
      end
    end
    -- `{ fail_reason = ... }`, not a bare string: MiniTest reads
    -- `opts.fail_reason` off the third argument (mini/test.lua:700-704), so
    -- a plain string was silently discarded and this case had been failing
    -- with the generic "Failed expectation for equality" all along.
    expect.equality(found, true, {
      fail_reason = string.format("%s not in get_files(%q, %q)", path, lang, query),
    })
  end,
})

-- ── F# cons operator rendering ─────────────────────────────────────────
local FS_SNIPPET = table.concat({
  "let cons x xs = x :: xs",
  "let f lst =",
  "    match lst with",
  "    | h :: t -> t",
  "    | [] -> []",
}, "\n")

local function cons_captures_at(row, col)
  return child.lua_get(string.format(
    [[(function()
      local caps = vim.treesitter.get_captures_at_pos(0, %d, %d)
      local out = {}
      for _, c in ipairs(caps) do
        -- metadata.priority is a string ("110") when set via #set!
        out[c.capture] = tostring(c.metadata.priority)
      end
      return out
    end)()]],
    row,
    col
  ))
end

-- Temp file managed across the whole set (MiniTest.finally is per-case,
-- so cleanup happens in post_once instead of with_temp_dir).
local fs_probe_dir

T["fsharp rendering"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      fs_probe_dir = vim.fn.tempname()
      vim.fn.mkdir(fs_probe_dir, "p")
      local path = fs_probe_dir .. "/cons_probe.fs"
      vim.fn.writefile(vim.split(FS_SNIPPET, "\n"), path)
      child.lua(string.format("vim.cmd.edit(%q)", path))
      -- Ensure the parser has run before capture queries.
      child.lua([[
        local ok, parser = pcall(vim.treesitter.get_parser, 0, "fsharp")
        if ok and parser then parser:parse() end
      ]])
    end,
    post_once = function()
      child.stop()
      if fs_probe_dir then
        vim.fn.delete(fs_probe_dir, "rf")
      end
    end,
  },
})

T["fsharp rendering"]["cons captured in expression position"] = function()
  -- line 1: "let cons x xs = x :: xs", :: at 0-based col 18
  local caps = cons_captures_at(0, 18)
  expect.equality(caps["operator.cons.fsharp"], "110")
end

T["fsharp rendering"]["cons captured in match-pattern position"] = function()
  -- line 4: "    | h :: t -> t", :: at 0-based col 8
  local caps = cons_captures_at(3, 8)
  expect.equality(caps["operator.cons.fsharp"], "110")
end

T["fsharp rendering"]["cons group resolves to pink"] = function()
  local fg = child.lua_get(
    [[vim.api.nvim_get_hl(0, { name = "@operator.cons.fsharp", link = false }).fg]]
  )
  expect.equality(fg, 16106215) -- 0xf5c2e7
end

T["fsharp rendering"]["after-query delimiter rule is active"] = function()
  -- The ";; extends" regression: if after/queries/fsharp/highlights.scm
  -- is dropped again, punctuation.delimiter disappears from the combined
  -- query's captures.
  local has = child.lua_get([[(function()
    local q = vim.treesitter.query.get("fsharp", "highlights")
    if not q then return false end
    for _, cap in ipairs(q.captures) do
      if cap == "punctuation.delimiter" then return true end
    end
    return false
  end)()]])
  expect.equality(has, true)
end

return T
