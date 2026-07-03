local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["setup"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

T["setup"]["config loads without errors"] = function()
  expect.equality(child.lua_get("vim.v.errmsg"), "")
end

T["setup"]["lazy.nvim loaded"] = function()
  local count = child.lua_get([[require("lazy").stats().count]])
  expect.equality(count > 0, true)
end

T["setup"]["plugin count >= 24"] = function()
  local count = child.lua_get([[require("lazy").stats().count]])
  expect.equality(count >= 24, true)
end

-- ── custom modules load ────────────────────────────────────────────────────
local modules = {
  "config.roots",
  "config.remark_auto",
  "config.shebang",
  "config.uv_init",
  "config.fsharp-highlights",
  "config.fsharp.highlights",
  "config.fsharp.du_refs",
  "config.fsharp.constraints",
  "config.fsharp.fsi",
  "config.fsharp.lsp",
  "config.fsharp.editorconfig",
  "config.fsharp.splitter",
  "config.markdown.config_ensure",
  "config.markdown.export",
  "config.markdown.math_delims",
  "config.markdown.peek_auto",
  "config.telescope.multigrep",
  "custom.fsharp_helpers",
  "capture_report",
  "ts_info",
  "config.spthy_setup",
}

T["setup"]["custom modules load"] = new_set({
  parametrize = (function()
    local p = {}
    for _, m in ipairs(modules) do
      table.insert(p, { m })
    end
    return p
  end)(),
}, {
  test = function(mod)
    local ok = child.lua_get(
      string.format([[pcall(require, %q)]], mod)
    )
    expect.equality(ok, true)
  end,
})

-- ── LSP configs parse ──────────────────────────────────────────────────────
local lsp_files = { "marksman", "remark_ls", "bashls", "basedpyright", "lua_ls", "ruff" }

T["setup"]["lsp configs return tables"] = new_set({
  parametrize = (function()
    local p = {}
    for _, f in ipairs(lsp_files) do
      table.insert(p, { f })
    end
    return p
  end)(),
}, {
  test = function(name)
    local cfg_dir = vim.fn.stdpath("config")
    local path = cfg_dir .. "/lsp/" .. name .. ".lua"
    local ok, result = pcall(dofile, path)
    expect.equality(ok, true)
    expect.equality(type(result), "table")
  end,
})

return T
