-- tests/test_lean_fork.lua — the lean.nvim fork pin, and the invariant that
-- keeps the other machines working.
--
-- This machine runs a permanently local fork of lean.nvim (decisions.md D15,
-- and FORK-CHANGES.md inside the fork). ~/.config/nvim is a chezmoi external
-- shared with WorkBox and main, which have no fork, so there are two live
-- configurations and the dangerous one is the one this machine never sees.
--
-- The invariant under test is not "the pin works". It is:
--
--     EXACTLY ONE of {the fork's in-tree fixes, the config's wrappers} is
--     active. Never both, never neither.
--
-- "Never neither" is a silent regression on WorkBox: the Loogle crash comes
-- back and nobody here would ever notice. "Never both" is double-wrapping
-- loogle.search, which is benign today but is the sort of thing that becomes a
-- confusing bug the moment either side stops being idempotent.
--
-- Both branches are exercised for real, by restarting a child with
-- $LEAN_NVIM_FORK_DIR pointed at a path that does not exist. Asserting only the
-- branch this machine happens to be on would be a test that cannot fail where
-- it matters.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")

local child = MiniTest.new_child_neovim()
local T = new_set({
  hooks = {
    pre_case = function()
      H.setup_child(child)
    end,
    post_once = child.stop,
  },
})

T["lean fork"] = new_set()

---Restart the child with the fork forced absent, and load lean.nvim.
local function restart_without_fork()
  local args = vim.deepcopy(H.child_args)
  vim.list_extend(args, { "--cmd", "let $LEAN_NVIM_FORK_DIR = '/nonexistent/lean-nvim-rich'" })
  child.restart(args)
  child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
  child.lua([[pcall(require("lazy").load, { plugins = { "lean.nvim" } })]])
end

local function restart_with_fork()
  H.setup_child(child)
  child.lua([[pcall(require("lazy").load, { plugins = { "lean.nvim" } })]])
end

-- ── The pin resolves, and resolves to a tree that has a plugin in it ────────

T["lean fork"]["the fork is what this machine actually loads"] = function()
  restart_with_fork()
  local enabled = child.lua_get([[require("config.lean.fork").enabled()]])
  expect.equality(enabled, true)

  -- Measured through the runtimepath, not read back off our own config: the
  -- question is where `require("lean")` comes from, and only nvim can answer
  -- that.
  local found = child.lua_get([[vim.api.nvim_get_runtime_file("lua/lean/init.lua", true)]])
  expect.equality(#found, 1)
  expect.equality(found[1], child.lua_get([[require("config.lean.fork").dir()]]) .. "/lua/lean/init.lua")

  -- lazy must treat it as local, or `:Lazy update` would try to manage a repo
  -- whose push URL is deliberately disabled.
  expect.equality(child.lua_get([[require("lazy.core.config").plugins["lean.nvim"]._.is_local]]), true)
end

T["lean fork"]["the existence test stats a file, not the directory"] = function()
  -- A leftover empty directory, or one holding nothing but .git, passes a
  -- directory stat and would pin lazy at a tree with no plugin in it — Lean
  -- support gone, on the machine where it matters most.
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. "/lua/lean", "p")
  local args = vim.deepcopy(H.child_args)
  vim.list_extend(args, { "--cmd", "let $LEAN_NVIM_FORK_DIR = '" .. dir .. "'" })
  child.restart(args)
  child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])

  expect.equality(child.lua_get([[require("config.lean.fork").enabled()]]), false)
  vim.fn.delete(dir, "rf")
end

-- ── The fallback, which is the branch this machine never runs ───────────────

T["lean fork"]["without the fork, lean.nvim comes from lazy's own clone"] = function()
  restart_without_fork()
  expect.equality(child.lua_get([[require("config.lean.fork").enabled()]]), false)

  local found = child.lua_get([[vim.api.nvim_get_runtime_file("lua/lean/init.lua", true)]])
  expect.equality(#found, 1)
  expect.equality(found[1]:find("/lazy/lean.nvim/", 1, true) ~= nil, true)
end

-- ── The invariant itself ────────────────────────────────────────────────────

T["lean fork"]["exactly one of fork-fixes and config-wrappers is active"] = function()
  -- On the fork: setup() applies nothing, because the fixes are in-tree.
  restart_with_fork()
  expect.equality(child.lua_get([[require("config.lean.upstream_fixes").setup()]]), {})

  -- Off the fork: setup() applies all three, by name. A list, not a count —
  -- a count would keep passing if one fix were replaced by another.
  restart_without_fork()
  expect.equality(child.lua_get([[require("config.lean.upstream_fixes").setup()]]), {
    "satellite_winbuf_pred",
    "loogle_search",
    "loogle_finder",
  })
end

T["lean fork"]["the fork carries the three fixes the wrappers would have applied"] = function()
  -- The other half of "never neither": if a rebase ever drops an in-tree fix,
  -- this machine loses it silently, because upstream_fixes has already decided
  -- not to run. Assert against the fork's source, since the defects are all
  -- shapes of code rather than observable state at rest.
  restart_with_fork()
  local dir = child.lua_get([[require("config.lean.fork").dir()]])

  -- Comment lines are stripped first. The fork's own comments quote the wrong
  -- spellings in order to explain why they are wrong — `not pred()` appears
  -- verbatim in the M3 comment — so a naive text search matches the
  -- explanation and reports the defect it is warning about. Caught by this
  -- test failing on a correct tree.
  local function slurp(rel)
    local code = {}
    for _, line in ipairs(vim.fn.readfile(dir .. "/" .. rel)) do
      if not line:match("^%s*%-%-") then
        code[#code + 1] = line
      end
    end
    return table.concat(code, "\n")
  end

  -- M1: no error() left on the status path.
  local loogle = slurp("lua/lean/loogle.lua")
  expect.equality(loogle:find("error('Loogle returned status code", 1, true), nil)
  expect.equality(loogle:find("return nil, 'Loogle returned status code", 1, true) ~= nil, true)

  -- M2: neither of the finder's two nil returns survives.
  local finder = slurp("lua/telescope/_extensions/loogle.lua")
  expect.equality(finder:find("return results\n", 1, true), nil)
  expect.equality(finder:find("return results or {}", 1, true) ~= nil, true)

  -- M3: util.winbuf_pred, and the early abort spelled the way satellite spells
  -- it. `not pred()` would abort every render — winbuf_pred returns false or
  -- implicitly nil, never true.
  local satellite = slurp("lua/lean/satellite.lua")
  expect.equality(satellite:find("async.winbuf_pred", 1, true), nil)
  expect.equality(satellite:find("util.winbuf_pred(bufnr, winid)", 1, true) ~= nil, true)
  expect.equality(satellite:find("if not pred()", 1, true), nil)
  expect.equality(satellite:find("if pred() == false then", 1, true) ~= nil, true)
end

T["lean fork"]["the wrapper survives being applied twice"] = function()
  -- Repeated setup() must not change what search answers. Not a hypothetical:
  -- lazy re-running a plugin's `config`, or a `:source` of the plugin spec,
  -- would call it again. No network — vim.system is stubbed in the child, so
  -- this exercises the wrapper rather than Loogle's uptime.
  restart_without_fork()
  child.lua([[
    local function answer(status, body)
      return function() return { code = 0, stdout = body, stderr = status } end
    end
    vim.system = function() return { wait = answer("500", "boom") } end

    local fixes = require("config.lean.upstream_fixes")
    fixes.setup()
    fixes.setup()

    local results, err = require("lean.loogle").search("abc")
    _G.__fork_test = { results = results, err = err, rtype = type(results) }
  ]])
  -- Upstream would have thrown out of here; wrapped, it must be a table.
  expect.equality(child.lua_get([[_G.__fork_test.rtype]]), "table")
  expect.equality(child.lua_get([[type(_G.__fork_test.err)]]), "string")
end

return T
