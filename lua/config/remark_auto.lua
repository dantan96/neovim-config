-- Automatically bootstrap a remark workspace for markdown files opened anywhere
-- under ~ (but not in ~ itself).
--
-- Strategy:
--   • remark-gfm is installed ONCE to ~/.config/.remarks/node_modules/ (central hub).
--   • Each remarkified directory gets only two tiny artefacts:
--       .remarkrc.json   {"plugins":["remark-gfm"]}
--       node_modules  →  ~/.config/.remarks/node_modules  (symlink, ~50 bytes)
--   • Node.js follows the symlink, so remark finds the plugin via normal resolution.
--   • The central npm install is fired detached (nohup … &) so it outlives Neovim.
--   • Every remarkified directory is recorded in ~/.config/.remarks/index.json.

local M = {}

local REMARKS_DIR    = vim.fn.expand("~/.config/.remarks")
local CENTRAL_PKGS   = REMARKS_DIR .. "/node_modules"
local INDEX_FILE     = REMARKS_DIR .. "/index.json"
local REMARKRC       = ".remarkrc.json"
local REMARKRC_BODY  = '{\n  "plugins": ["remark-gfm"]\n}\n'

-- Roots processed this session — avoid redundant work.
local done = {} ---@type table<string, true>

-- ── root detection ────────────────────────────────────────────────────────────

-- Returns the directory that should receive .remarkrc.json, or nil if no action
-- is needed. Walks up from the file's directory toward ~:
--   • Any existing remark config or remark-gfm install → already done, return nil.
--   • First .git found → use that directory (project root).
--   • No .git found → use the file's own directory (not the first-level home subdir).
local function find_init_root(filepath)
  local home = vim.fn.expand("~")
  local dir  = vim.fs.dirname(vim.fn.fnamemodify(filepath, ":p"))

  if dir == home then return nil end
  if not vim.startswith(dir .. "/", home .. "/") then return nil end

  local candidate = dir
  while candidate ~= home do
    -- Already configured anywhere up the tree → nothing to do.
    for _, name in ipairs({ REMARKRC, ".remarkrc", ".remarkrc.mjs",
                             ".remarkrc.js", ".remarkrc.yml", ".remarkrc.yaml" }) do
      if vim.uv.fs_stat(candidate .. "/" .. name) then return nil end
    end
    if vim.uv.fs_stat(candidate .. "/node_modules/remark-gfm") then return nil end

    if vim.uv.fs_stat(candidate .. "/.git") then return candidate end

    local parent = vim.fs.dirname(candidate)
    if parent == candidate then break end
    candidate = parent
  end

  return dir  -- no .git found: use the file's own directory
end

-- ── central install ──────────────────────────────────────────────────────────

local central_install_triggered = false

local function ensure_central_install()
  if central_install_triggered then return end
  if vim.uv.fs_stat(CENTRAL_PKGS .. "/remark-gfm") then return end
  central_install_triggered = true

  vim.uv.fs_mkdir(REMARKS_DIR, 493, function() end) -- 493 = 0o755

  if not vim.uv.fs_stat(REMARKS_DIR .. "/package.json") then
    local f = io.open(REMARKS_DIR .. "/package.json", "w")
    if f then f:write('{"private":true}\n') f:close() end
  end

  -- Fire async: npm runs in background, notifies on failure.
  vim.fn.jobstart({ "npm", "install", "remark-gfm" }, {
    cwd = REMARKS_DIR,
    detach = true,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("remark-gfm install failed (exit " .. code .. ")", vim.log.levels.WARN)
        end)
      end
    end,
  })
end

-- ── index ─────────────────────────────────────────────────────────────────────

local function read_index()
  local f = io.open(INDEX_FILE, "r")
  if not f then return { version = 1, entries = {} } end
  local raw = f:read("*a") f:close()
  local ok, data = pcall(vim.json.decode, raw)
  return (ok and type(data) == "table") and data or { version = 1, entries = {} }
end

local function write_index(data)
  local f = io.open(INDEX_FILE, "w")
  if f then f:write(vim.json.encode(data) .. "\n") f:close() end
end

local function index_add(dir)
  local data = read_index()
  for _, e in ipairs(data.entries or {}) do
    if e.dir == dir then return end  -- already present
  end
  local id = 1
  for _, e in ipairs(data.entries or {}) do
    if (e.id or 0) >= id then id = e.id + 1 end
  end
  table.insert(data.entries, {
    id = id,
    dir = dir,
    created = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })
  write_index(data)
end

-- ── gitignore ─────────────────────────────────────────────────────────────────

local function ensure_gitignored(dir)
  local gi = dir .. "/.gitignore"
  -- Only touch .gitignore if the directory is a git repo or already has one.
  if not vim.uv.fs_stat(dir .. "/.git") and not vim.uv.fs_stat(gi) then return end
  local existing = ""
  local f = io.open(gi, "r")
  if f then existing = f:read("*a") f:close() end
  if existing:find("node_modules", 1, true) then return end
  local out = io.open(gi, "a")
  if out then out:write("\nnode_modules\n") out:close() end
end

-- ── main entry ────────────────────────────────────────────────────────────────

local function remarkify(root)
  if done[root] then return end
  done[root] = true

  ensure_central_install()

  -- .remarkrc.json
  local rc = root .. "/" .. REMARKRC
  if not vim.uv.fs_stat(rc) then
    local f = io.open(rc, "w")
    if f then f:write(REMARKRC_BODY) f:close() end
  end

  -- node_modules symlink → central hub
  local link = root .. "/node_modules"
  if not vim.uv.fs_stat(link) then
    vim.uv.fs_symlink(CENTRAL_PKGS, link, { junction = false }, function() end)
  end

  index_add(root)
  ensure_gitignored(root)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
      local path = vim.api.nvim_buf_get_name(args.buf)
      if path == "" then return end
      local root = find_init_root(path)
      if root then remarkify(root) end
    end,
  })
end

return M
