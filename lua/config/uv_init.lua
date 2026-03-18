local M = {}

-- "latest"  → let uv pick the newest Python it can find (recommended)
-- "minimum" → run vermin and use the lowest version that works
-- "3.x"     → pin a specific version (e.g. "3.12")
M.python_version = "latest"

local BASEDPYRIGHT_TOML = [[

[tool.basedpyright]
typeCheckingMode = "standard"
venvPath = "."
venv = ".venv"
]]

local function err(msg)
  vim.notify("UvInit: " .. msg, vim.log.levels.ERROR)
end

-- Run vermin on `filepath` and return the minimum Python version string
-- (e.g. "3.8"), or nil if it cannot be determined.
-- Vermin may output "2.0, 3.0" for scripts with no Python-3-specific syntax;
-- "3.0" is not a useful floor, so we only return a version when vermin finds
-- a meaningful Python 3 minimum (3.1 or higher).
local function detect_min_python(filepath)
  local r = vim.system(
    { "uvx", "vermin", "--no-tips", "--eval-annotations", filepath },
    { text = true }
  ):wait()
  if r.code ~= 0 then return nil end
  local line = (r.stdout or ""):match("Minimum required versions:[^\n]*")
  if not line then return nil end
  local best_minor = nil
  for major, minor in line:gmatch("(%d+)%.(%d+)") do
    major, minor = tonumber(major), tonumber(minor)
    if major == 3 and minor > 0 then
      if not best_minor or minor > best_minor then
        best_minor = minor
      end
    end
  end
  if not best_minor then return nil end
  return "3." .. math.max(best_minor, 8) -- uv requires Python >= 3.8
end

-- Run pipreqs --print on `dir` and return a list of package names.
local function detect_packages(dir)
  local r = vim.system(
    { "uvx", "pipreqs", "--print", "--ignore", ".venv", dir },
    { text = true }
  ):wait()
  if r.code ~= 0 or not r.stdout then return {} end
  local pkgs = {}
  for line in r.stdout:gmatch("[^\n]+") do
    local name = line:match("^([A-Za-z0-9_%-%.]+)[=><!]")
    if name then table.insert(pkgs, name) end
  end
  return pkgs
end

local UV_SHEBANG = "#!/usr/bin/env -S uv run"

-- Ensure `filepath` has the correct uv shebang, and chmod +x.
-- If no shebang: prepend it.
-- If a different shebang: replace it with the correct one.
-- If already correct: leave it alone.
local function ensure_shebang(filepath)
  local sf = io.open(filepath, "r")
  if not sf then return end
  local content = sf:read("*a")
  sf:close()

  local existing = content:match("^(#![^\n]*)\n?")
  if existing == UV_SHEBANG then
    -- already correct
  elseif existing then
    -- wrong shebang — replace first line
    local rest = content:match("^[^\n]*\n?(.*)")  or ""
    local wf = io.open(filepath, "w")
    if wf then wf:write(UV_SHEBANG .. "\n" .. rest) ; wf:close() end
  else
    -- no shebang — prepend
    local wf = io.open(filepath, "w")
    if wf then wf:write(UV_SHEBANG .. "\n" .. content) ; wf:close() end
  end
  vim.system({ "chmod", "+x", filepath }):wait()
end

-- Append [tool.basedpyright] to `toml_path` if the section is not yet present.
local function ensure_basedpyright(toml_path)
  local rf = io.open(toml_path, "r")
  if not rf then return end
  local content = rf:read("*a")
  rf:close()
  if content:find("[tool.basedpyright]", 1, true) then return end
  local af = io.open(toml_path, "a")
  if af then
    af:write(BASEDPYRIGHT_TOML)
    af:close()
  end
end

-- Repair mode: file is already inside an existing project.
local function repair(src, proj_dir)
  -- Ensure .venv exists
  if vim.fn.isdirectory(proj_dir .. "/.venv") == 0 then
    vim.system({ "uv", "venv" }, { cwd = proj_dir, text = true }):wait()
    vim.system({ "uv", "sync" }, { cwd = proj_dir, text = true }):wait()
  end

  -- Detect and add any missing deps
  local packages = detect_packages(proj_dir)
  if #packages > 0 then
    local add_cmd = vim.list_extend({ "uv", "add" }, packages)
    local add = vim.system(add_cmd, { cwd = proj_dir, text = true }):wait()
    if add.code ~= 0 then
      vim.notify(
        "UvInit: uv add failed:\n" .. (add.stderr or ""),
        vim.log.levels.WARN
      )
    end
  end

  ensure_shebang(src)
  ensure_basedpyright(proj_dir .. "/pyproject.toml")

  local dep_info = #packages > 0
    and (" — added: " .. table.concat(packages, ", "))
    or  " — no new deps detected"
  vim.notify("UvInit: repaired project at " .. proj_dir .. dep_info, vim.log.levels.INFO)
end

function M.run(name_arg)
  -- Guard: must be a saved .py file
  local src = vim.api.nvim_buf_get_name(0)
  if src == "" then
    return err("save the file before running UvInit")
  end
  if not src:match("%.py$") then
    return err("current buffer is not a .py file")
  end

  -- Guard: uv must be available
  if vim.fn.executable("uv") == 0 then
    return err("uv not found in PATH (install with: brew install uv)")
  end

  -- If already inside a project, switch to repair mode instead
  local existing = vim.fs.find({ "pyproject.toml", "uv.lock" }, {
    path = vim.fn.fnamemodify(src, ":h"),
    upward = true,
    limit = 1,
  })[1]
  if existing then
    return repair(src, vim.fs.dirname(existing))
  end

  local basename   = vim.fn.fnamemodify(src, ":t")   -- myscript.py
  local parent_dir = vim.fn.fnamemodify(src, ":h")   -- /path/to
  local stem       = vim.fn.fnamemodify(src, ":t:r") -- myscript
  local proj_name  = name_arg or stem
  local proj_dir   = parent_dir .. "/" .. proj_name

  -- Guard: target directory must not exist
  if vim.fn.isdirectory(proj_dir) == 1 then
    return err("directory already exists: " .. proj_dir)
  end

  -- Step 1: resolve Python version for uv init
  local init_cmd = { "uv", "init", "--name", proj_name, "--no-readme" }
  local python_ver
  if M.python_version == "latest" then
    -- let uv pick the newest available Python; don't pass --python
  elseif M.python_version == "minimum" then
    python_ver = detect_min_python(src)
    if python_ver then vim.list_extend(init_cmd, { "--python", python_ver }) end
  else
    python_ver = M.python_version
    vim.list_extend(init_cmd, { "--python", python_ver })
  end
  vim.list_extend(init_cmd, { proj_dir })

  -- Step 2: uv init
  local init_result = vim.system(init_cmd, { text = true }):wait()
  if init_result.code ~= 0 then
    return err("uv init failed:\n" .. (init_result.stderr or ""))
  end

  -- Step 3: remove the stub main.py uv creates, move our script in
  vim.fn.delete(proj_dir .. "/main.py")
  local old_bufnr = vim.api.nvim_get_current_buf()
  local new_path  = proj_dir .. "/" .. basename
  local mv = vim.system({ "mv", src, new_path }, { text = true }):wait()
  if mv.code ~= 0 then
    return err("could not move file:\n" .. (mv.stderr or ""))
  end

  -- Step 4: shebang + chmod +x
  ensure_shebang(new_path)

  -- Step 5: detect third-party packages via pipreqs
  local packages = detect_packages(proj_dir)

  -- Step 6: uv add detected packages (also creates .venv)
  if #packages > 0 then
    local add_cmd = vim.list_extend({ "uv", "add" }, packages)
    local add = vim.system(add_cmd, { cwd = proj_dir, text = true }):wait()
    if add.code ~= 0 then
      vim.notify(
        "UvInit: uv add failed (project created, deps not installed):\n" .. (add.stderr or ""),
        vim.log.levels.WARN
      )
    end
  else
    vim.system({ "uv", "venv" }, { cwd = proj_dir }):wait()
  end

  -- Step 7: append [tool.basedpyright] to pyproject.toml
  ensure_basedpyright(proj_dir .. "/pyproject.toml")

  -- Step 8: open moved file, close stale buffer
  vim.cmd("edit " .. vim.fn.fnameescape(new_path))
  if vim.api.nvim_buf_is_valid(old_bufnr) then
    vim.cmd("bdelete " .. old_bufnr)
  end

  local ver_info = python_ver and (" (python >=" .. python_ver .. ")") or ""
  local dep_info = #packages > 0
    and (" — added: " .. table.concat(packages, ", "))
    or  " — no third-party imports detected"
  vim.notify("UvInit: project created at " .. proj_dir .. ver_info .. dep_info, vim.log.levels.INFO)
end

function M.setup()
  vim.api.nvim_create_user_command("UvInit", function(opts)
    M.run(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Scaffold uv project around current .py file" })
end

return M
