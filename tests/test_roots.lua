local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local roots = require("config.roots")

-- ── marker tables ──────────────────────────────────────────────────────────
T["markers"] = new_set()

T["markers"]["marksman_markers non-empty"] = function()
  expect.equality(#roots.marksman_markers > 0, true)
end

T["markers"]["remark_markers non-empty"] = function()
  expect.equality(#roots.remark_markers > 0, true)
end

T["markers"]["all_markers combines both"] = function()
  expect.equality(
    #roots.all_markers >= #roots.marksman_markers + #roots.remark_markers,
    true
  )
end

-- ── find() ─────────────────────────────────────────────────────────────────
T["find"] = new_set()

T["find"]["returns root when .git found"] = function()
  H.with_temp_dir(function(dir)
    vim.fn.mkdir(dir .. "/sub", "p")
    vim.fn.mkdir(dir .. "/.git", "p")
    local result = roots.find(dir .. "/sub/file.md", roots.marksman_markers)
    expect.equality(result, dir)
  end)
end

T["find"]["returns nil when root would be home"] = function()
  local home = vim.fn.expand("~")
  vim.fn.mkdir(home .. "/.git", "p")
  MiniTest.finally(function()
    vim.fn.delete(home .. "/.git", "rf")
  end)
  local result = roots.find(home .. "/somefile.md", { ".git" })
  expect.equality(result, nil)
end

T["find"]["returns dirname when no markers found"] = function()
  H.with_temp_dir(function(dir)
    vim.fn.mkdir(dir .. "/sub", "p")
    local result = roots.find(dir .. "/sub/file.md", { ".nonexistent_marker" })
    expect.equality(result, dir .. "/sub")
  end)
end

T["find"]["avoids config dir for non-config paths"] = function()
  -- When a marker is found in the nvim config dir but the file is elsewhere,
  -- roots.find() should fall back to the file's dirname
  H.with_temp_dir(function(dir)
    local cfgdir = vim.fn.stdpath("config")
    -- start is outside cfgdir, but markers could match up to cfgdir
    -- use a marker that exists in cfgdir (init.lua exists there)
    local result = roots.find(dir .. "/file.md", { "init.lua" })
    -- Should NOT return cfgdir; should return dir instead
    if result then
      expect.equality(result:find(cfgdir, 1, true) == nil or dir:find(cfgdir, 1, true) ~= nil, true)
    end
  end)
end

T["find"]["nil start falls back without error"] = function()
  expect.no_error(function()
    roots.find(nil, { ".git" })
  end)
end

T["find"]["directory start with no markers returns the directory itself"] = function()
  H.with_temp_dir(function(dir)
    vim.fn.mkdir(dir .. "/sub", "p")
    -- start is a directory, not a file: fallback must be that directory,
    -- not its parent
    local result = roots.find(dir .. "/sub", { ".nonexistent_marker" })
    expect.equality(result, dir .. "/sub")
  end)
end

T["find"]["unnamed buffer falls back to cwd, not its parent"] = function()
  H.with_temp_dir(function(dir)
    vim.fn.mkdir(dir .. "/sub", "p")
    local prev_buf = vim.api.nvim_get_current_buf()
    local prev_cwd = vim.fn.getcwd()
    local buf = vim.api.nvim_create_buf(false, false) -- unnamed, listed=false
    vim.api.nvim_set_current_buf(buf)
    vim.cmd.cd(vim.fn.fnameescape(dir .. "/sub"))
    MiniTest.finally(function()
      vim.cmd.cd(vim.fn.fnameescape(prev_cwd))
      vim.api.nvim_set_current_buf(prev_buf)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
    local result = roots.find(nil, { ".nonexistent_marker" })
    -- getcwd() may resolve symlinks (/var -> /private/var on macOS), so
    -- compare realpaths; the point is: cwd itself, NOT its parent.
    expect.equality(
      result and vim.uv.fs_realpath(result),
      vim.uv.fs_realpath(dir .. "/sub")
    )
  end)
end

-- ── find_marksman_config() ─────────────────────────────────────────────────
T["find_marksman_config"] = new_set()

T["find_marksman_config"]["finds .marksman.toml"] = function()
  H.with_temp_dir(function(dir)
    local f = io.open(dir .. "/.marksman.toml", "w")
    f:write("")
    f:close()
    expect.equality(roots.find_marksman_config(dir), dir .. "/.marksman.toml")
  end)
end

T["find_marksman_config"]["finds marksman.toml"] = function()
  H.with_temp_dir(function(dir)
    local f = io.open(dir .. "/marksman.toml", "w")
    f:write("")
    f:close()
    expect.equality(roots.find_marksman_config(dir), dir .. "/marksman.toml")
  end)
end

T["find_marksman_config"]["returns nil when no config"] = function()
  H.with_temp_dir(function(dir)
    expect.equality(roots.find_marksman_config(dir), nil)
  end)
end

T["find_marksman_config"]["returns nil for nil root"] = function()
  expect.equality(roots.find_marksman_config(nil), nil)
end

-- ── find_remark_config() ───────────────────────────────────────────────────
T["find_remark_config"] = new_set()

T["find_remark_config"]["finds .remarkrc.json"] = function()
  H.with_temp_dir(function(dir)
    local f = io.open(dir .. "/.remarkrc.json", "w")
    f:write("")
    f:close()
    expect.equality(roots.find_remark_config(dir), dir .. "/.remarkrc.json")
  end)
end

T["find_remark_config"]["finds .remarkrc.mjs"] = function()
  H.with_temp_dir(function(dir)
    local f = io.open(dir .. "/.remarkrc.mjs", "w")
    f:write("")
    f:close()
    expect.equality(roots.find_remark_config(dir), dir .. "/.remarkrc.mjs")
  end)
end

T["find_remark_config"]["returns nil when no config"] = function()
  H.with_temp_dir(function(dir)
    expect.equality(roots.find_remark_config(dir), nil)
  end)
end

T["find_remark_config"]["returns nil for nil root"] = function()
  expect.equality(roots.find_remark_config(nil), nil)
end

return T
