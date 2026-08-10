local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local H = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

T["lsp configs"] = new_set()

local function load_lsp(name)
  local path = H.lsp_config_path(name)
  assert(path, "No lsp config found for " .. name .. " (checked lsp/ and after/lsp/)")
  local ok, result = pcall(dofile, path)
  assert(ok, "Failed to load " .. name .. ": " .. tostring(result))
  return result
end

T["lsp configs"]["marksman has root_dir function"] = function()
  local c = load_lsp("marksman")
  expect.equality(type(c.root_dir), "function")
end

T["lsp configs"]["no config uses single_file_support (not a vim.lsp.config field)"] = function()
  for _, name in ipairs({ "marksman", "remark_ls" }) do
    local c = load_lsp(name)
    expect.equality(c.single_file_support, nil)
  end
end

T["lsp configs"]["remark_ls filetypes includes markdown"] = function()
  local c = load_lsp("remark_ls")
  local found = vim.tbl_contains(c.filetypes, "markdown")
  expect.equality(found, true)
end

T["lsp configs"]["remark_ls has root_dir function"] = function()
  local c = load_lsp("remark_ls")
  expect.equality(type(c.root_dir), "function")
end

T["lsp configs"]["bashls filetypes includes sh and bash but not zsh"] = function()
  local c = load_lsp("bashls")
  for _, ft in ipairs({ "sh", "bash" }) do
    expect.equality(vim.tbl_contains(c.filetypes, ft), true)
  end
  -- shellcheck/shfmt do not support zsh; bashls must not attach to it
  expect.equality(vim.tbl_contains(c.filetypes, "zsh"), false)
end

T["lsp configs"]["basedpyright has typeCheckingMode"] = function()
  local c = load_lsp("basedpyright")
  local mode = c.settings.basedpyright.analysis.typeCheckingMode
  expect.equality(type(mode), "string")
end

-- ── Declared values must survive into the resolved config ──────────────────
-- The cases above only prove a file PARSES and says what we meant. They
-- cannot see the bug that actually keeps biting: nvim-lspconfig ships its
-- own lsp/<name>.lua later in the runtimepath, so any key of ours that
-- COLLIDES with theirs loses the tbl_deep_extend and is silently dropped.
-- Three instances so far — remark_ls filetypes (35d1c1d), raku_navigator
-- (25f9964), bashls globPattern (this one, .env never indexed). Each was
-- found by hand; this quantifies over every config so the next one fails
-- a test instead.
--
-- Containment, not equality: lspconfig legitimately ADDS keys we don't set
-- (basedpyright and lua_ls settings come back as supersets), and list
-- order is not meaningful to any consumer here (taplo declares
-- root_markers in a different order than lspconfig). So the assertion is
-- that every leaf we declare is present in the resolved config — which
-- still fails loudly on a scalar being replaced or a list entry vanishing,
-- the two shapes this bug takes.
local child = MiniTest.new_child_neovim()

T["lsp resolution"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      -- lspconfig must be on the rtp for its lsp/ files to take part in
      -- the merge at all; it is lazy-loaded, so force it.
      child.lua([[pcall(require, "lspconfig")]])
    end,
    post_once = function() child.stop() end,
  },
})

T["lsp resolution"]["declared values survive the lspconfig merge"] = function()
  local violations = child.lua_get([[(function()
    local out = {}
    local function is_list(t) return #t > 0 or next(t) == nil end
    local function has(list, v)
      for _, x in ipairs(list) do
        if vim.deep_equal(x, v) then return true end
      end
      return false
    end
    local function check(ours, got, path, name)
      if type(ours) == "function" then return end
      if type(ours) ~= "table" then
        if not vim.deep_equal(ours, got) then
          table.insert(out, ("%s%s: declared %s, resolved %s")
            :format(name, path, vim.inspect(ours), vim.inspect(got)))
        end
      elseif type(got) ~= "table" then
        table.insert(out, ("%s%s: declared a table, resolved %s")
          :format(name, path, vim.inspect(got)))
      elseif is_list(ours) then
        for _, v in ipairs(ours) do
          if not has(got, v) then
            table.insert(out, ("%s%s: declared entry %s missing from resolved")
              :format(name, path, vim.inspect(v)))
          end
        end
      else
        for k, v in pairs(ours) do
          check(v, got[k], path .. "." .. k, name)
        end
      end
    end
    local cfg = vim.fn.stdpath("config")
    for _, dir in ipairs({ "/lsp/", "/after/lsp/" }) do
      for _, p in ipairs(vim.fn.glob(cfg .. dir .. "*.lua", false, true)) do
        local name = vim.fn.fnamemodify(p, ":t:r")
        local ok, ours = pcall(dofile, p)
        if ok and type(ours) == "table" then
          check(ours, vim.lsp.config[name] or {}, "", name)
        end
      end
    end
    return out
  end)()]])
  expect.equality(violations, {})
end

-- Containment above cannot catch an ADDED filetype, and this is the one
-- addition that matters: bashls shelling out to shellcheck on a zsh
-- script produces only false diagnostics.
T["lsp resolution"]["resolved bashls filetypes still exclude zsh"] = function()
  local fts = child.lua_get([[vim.lsp.config["bashls"].filetypes]])
  expect.equality(vim.tbl_contains(fts, "sh"), true)
  expect.equality(vim.tbl_contains(fts, "bash"), true)
  expect.equality(vim.tbl_contains(fts, "zsh"), false)
end

return T
