-- Regenerate the checked-in `.luarc.json`.
--
-- Why this file is checked in at all: lazydev.nvim only informs a
-- lua-language-server that Neovim itself started, with lazydev loaded. Every
-- other lua_ls -- an agent's, another editor's, `lua-language-server --check`,
-- and every `git worktree` of this repo -- sees no `vim`, no `MiniTest`, no
-- `Snacks` and no plugin types at all. A checked-in `.luarc.json` reaches all
-- of them, and a new worktree inherits it with zero setup.
--
-- Why it lists every plugin rather than deferring to lazydev: lua_ls applies
-- `.luarc.json` *after* the client's settings (provider.lua:66), so the rc's
-- `workspace.library` wholly replaces the one lazydev pushes over
-- `didChangeConfiguration`. Measured: with a four-entry rc,
-- `require("telescope.builtin")` hovered as `{ find_files: unknown }` instead
-- of telescope's real type. The rc therefore has to be a superset of what
-- lazydev would have supplied, which is every installed plugin.
--
--   make luarc
--
-- `tests/test_luarc.lua` fails if the checked-in file drifts from
-- `lazy-lock.json`, so adding a plugin is caught rather than silently
-- reintroducing undefined-field noise.

local M = {}

local HOME = assert(vim.env.HOME)

--- Render an absolute path as `~/...` when it is under $HOME, so the file
--- stays valid on the WorkBox and main branches. lua_ls expands a leading
--- `~` (utility.lua:771).
local function tildify(path)
  if path:sub(1, #HOME + 1) == HOME .. "/" then
    return "~" .. path:sub(#HOME + 1)
  end
  return path
end

--- lua_ls silently skips library entries that do not exist
--- (workspace.lua:241), so listing several runtime candidates costs nothing
--- and removes the need for a per-machine edit.
local function runtime_candidates()
  local out = {
    -- Set whenever lua_ls is a child of Neovim; resolved by lua_ls's
    -- `${env:...}` placeholder (files.lua `resolvePathPlaceholders`).
    "${env:VIMRUNTIME}",
  }
  local seen = { ["${env:VIMRUNTIME}"] = true }
  local function push(p)
    if p and p ~= "" and not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  push(tildify(vim.fs.normalize(vim.env.VIMRUNTIME or "")))
  -- Sibling bob channels, then the usual system installs.
  for _, chan in ipairs({ "nightly", "stable" }) do
    push(("~/.local/share/bob/%s/share/nvim/runtime"):format(chan))
  end
  push("/usr/local/share/nvim/runtime")
  push("/opt/homebrew/share/nvim/runtime")
  push("/usr/share/nvim/runtime")
  return out
end

--- Every plugin lazy.nvim has locked, as a library root. Roots, not their
--- `lua/` subdirectories: `runtime.path` below is `lua/?.lua`, and putting
--- `<root>/lua` in the library instead would also make lua_ls treat this
--- repo's own `lua/` as library code and stop diagnosing it.
local function plugin_roots(cfg_dir)
  local lock_path = cfg_dir .. "/lazy-lock.json"
  local fd = assert(io.open(lock_path, "r"), "cannot read " .. lock_path)
  local lock = vim.json.decode(fd:read("*a"))
  fd:close()
  local names = vim.tbl_keys(lock)
  table.sort(names, function(a, b)
    return a:lower() < b:lower()
  end)
  local lazy_root = tildify(vim.fs.normalize(vim.fn.stdpath("data") .. "/lazy"))
  return vim.tbl_map(function(name)
    return lazy_root .. "/" .. name
  end, names)
end

---@param cfg_dir string
---@return table
function M.build(cfg_dir)
  local library = runtime_candidates()
  -- luv's meta, for `vim.uv`.
  library[#library + 1] = "${3rd}/luv/library"
  vim.list_extend(library, plugin_roots(cfg_dir))
  return {
    ["$schema"] = "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
    runtime = {
      version = "LuaJIT",
      path = { "lua/?.lua", "lua/?/init.lua" },
      pathStrict = true,
    },
    workspace = {
      checkThirdParty = false,
      -- lua_ls applies `ignoreDir` to every library root as well as to the
      -- workspace (workspace.lua `getLibraryMatchers`). lazydev sets it to
      -- `{"/lua"}`, which -- since the rc does not override it -- silently
      -- excluded `$VIMRUNTIME/lua` and every `<plugin>/lua` and left `vim`
      -- undefined. Pin it back to lua_ls's own default.
      ignoreDir = { ".vscode" },
      -- Raised from the 5000 default: the plugin roots alone are ~3.5k files.
      maxPreload = 8000,
      library = library,
    },
  }
end

---@param cfg_dir string
---@return string
function M.render(cfg_dir)
  return vim.json.encode(M.build(cfg_dir))
end

function M.write(cfg_dir)
  cfg_dir = cfg_dir or vim.fn.stdpath("config")
  local path = cfg_dir .. "/.luarc.json"
  local json = M.render(cfg_dir)
  -- vim.json.encode emits one line in table-iteration order; pretty-print with
  -- sorted keys so the checked-in file has a stable, diffable shape.
  local pretty = vim.system({ "python3", "-m", "json.tool", "--indent", "2", "--sort-keys" }, { stdin = json }):wait()
  local out = pretty.code == 0 and pretty.stdout or json
  local fd = assert(io.open(path, "w"))
  fd:write(out)
  if out:sub(-1) ~= "\n" then
    fd:write("\n")
  end
  fd:close()
  return path
end

return M
