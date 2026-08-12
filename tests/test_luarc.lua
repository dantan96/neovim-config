-- The checked-in `.luarc.json` is what tells every lua-language-server that
-- is NOT a child of this Neovim -- an agent's, another editor's,
-- `lua-language-server --check`, and every git worktree of this repo -- where
-- the real Neovim and plugin definitions live. It is generated
-- (`make luarc`), so the failure mode is drift: install a plugin, forget to
-- regenerate, and `undefined-field` noise quietly returns for that plugin.
--
-- These assertions also pin the two settings whose absence silently defeats
-- the whole file. See scripts/gen_luarc.lua for why each one matters.
local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local H = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

local function read_json(path)
  local fd = assert(io.open(path, "r"), "cannot read " .. path)
  local raw = fd:read("*a")
  fd:close()
  return vim.json.decode(raw)
end

local function luarc()
  return read_json(H.cfg .. "/.luarc.json")
end

local function library_set()
  local set = {}
  for _, p in ipairs(luarc().workspace.library) do
    set[p] = true
  end
  return set
end

T["luarc"] = new_set()

T["luarc"][".luarc.json exists and parses"] = function()
  expect.equality(vim.uv.fs_stat(H.cfg .. "/.luarc.json") ~= nil, true)
  expect.equality(type(luarc()), "table")
end

T["luarc"]["declares the LuaJIT runtime and the lua/?.lua path convention"] = function()
  local rc = luarc()
  expect.equality(rc.runtime.version, "LuaJIT")
  expect.equality(rc.runtime.pathStrict, true)
  -- Library entries are plugin ROOTS, so the search path must include the
  -- `lua/` segment. Switching to the `?.lua` convention would silently stop
  -- resolving every require in the file.
  expect.equality(vim.tbl_contains(rc.runtime.path, "lua/?.lua"), true)
  expect.equality(vim.tbl_contains(rc.runtime.path, "lua/?/init.lua"), true)
end

T["luarc"]["does not ignore /lua"] = function()
  -- lua_ls applies workspace.ignoreDir to every LIBRARY root as well as to
  -- the workspace (workspace.lua getLibraryMatchers). lazydev pushes
  -- {"/lua"}; if the rc does not override it, every `<root>/lua` -- which is
  -- all of them -- is excluded and `vim` goes back to being undefined. This
  -- was measured, not theorised.
  for _, dir in ipairs(luarc().workspace.ignoreDir) do
    expect.equality(dir ~= "/lua", true)
  end
end

T["luarc"]["points at the Neovim runtime and luv"] = function()
  local lib = library_set()
  expect.equality(lib["${env:VIMRUNTIME}"], true)
  expect.equality(lib["${3rd}/luv/library"], true)
  -- At least one runtime candidate must exist on this machine, or `vim` is
  -- undefined for every lua_ls that is not a child of Neovim.
  local resolved = false
  for _, p in ipairs(luarc().workspace.library) do
    if p:find("nvim/runtime", 1, true) then
      local abs = p:gsub("^~", assert(vim.env.HOME))
      if vim.uv.fs_stat(abs .. "/lua/vim") then
        resolved = true
      end
    end
  end
  expect.equality(resolved, true)
end

T["luarc"]["covers every plugin in lazy-lock.json"] = function()
  local lock = read_json(H.cfg .. "/lazy-lock.json")
  local lib = library_set()
  local missing = {}
  for name in pairs(lock) do
    if not lib["~/.local/share/nvim/lazy/" .. name] then
      missing[#missing + 1] = name
    end
  end
  table.sort(missing)
  -- A non-empty list means `make luarc` has not been run since a plugin was
  -- added or removed.
  expect.equality(table.concat(missing, ", "), "")
end

T["luarc"]["is byte-identical to what the generator produces"] = function()
  local gen = dofile(H.cfg .. "/scripts/gen_luarc.lua")
  local on_disk = read_json(H.cfg .. "/.luarc.json")
  local fresh = gen.build(H.cfg)
  expect.equality(vim.deep_equal(on_disk, fresh), true)
end

return T
