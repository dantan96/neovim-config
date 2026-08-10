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

return T
