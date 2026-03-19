local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local cfg_dir = vim.fn.stdpath("config")

T["lsp configs"] = new_set()

local function load_lsp(name)
  local path = cfg_dir .. "/lsp/" .. name .. ".lua"
  local ok, result = pcall(dofile, path)
  assert(ok, "Failed to load " .. name .. ": " .. tostring(result))
  return result
end

T["lsp configs"]["marksman has root_dir function"] = function()
  local c = load_lsp("marksman")
  expect.equality(type(c.root_dir), "function")
end

T["lsp configs"]["marksman has single_file_support"] = function()
  local c = load_lsp("marksman")
  expect.equality(c.single_file_support, true)
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

T["lsp configs"]["bashls filetypes includes sh bash zsh"] = function()
  local c = load_lsp("bashls")
  for _, ft in ipairs({ "sh", "bash", "zsh" }) do
    expect.equality(vim.tbl_contains(c.filetypes, ft), true)
  end
end

T["lsp configs"]["basedpyright has typeCheckingMode"] = function()
  local c = load_lsp("basedpyright")
  local mode = c.settings.basedpyright.analysis.typeCheckingMode
  expect.equality(type(mode), "string")
end

return T
