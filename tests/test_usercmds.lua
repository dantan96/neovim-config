local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local child = MiniTest.new_child_neovim()
local cfg = vim.fn.stdpath("config")

T["usercmds"] = new_set({
  hooks = {
    pre_once = function()
      child.restart({ "-u", cfg .. "/init.lua", "--cmd", "set rtp^=" .. cfg })
      child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Helper to check command existence
local function cmd_exists(name)
  return child.lua_get(string.format(
    [[vim.fn.exists(":%s") == 2]], name
  ))
end

-- ── global commands ────────────────────────────────────────────────────────
local global_cmds = { "CapRep", "TSInfo", "UvInit" }

T["usercmds"]["global commands"] = new_set({
  parametrize = (function()
    local p = {}
    for _, c in ipairs(global_cmds) do
      table.insert(p, { c })
    end
    return p
  end)(),
}, {
  test = function(name)
    expect.equality(cmd_exists(name), true)
  end,
})

-- ── markdown commands (need .md buffer) ────────────────────────────────────
local md_cmds = {
  "MarksmanEnsureConfig",
  "RemarkEnsureConfig",
  "MarkdownEnsureConfigs",
  "MathDelimsToDollars",
  "DelimToggle",
  "ExportHTML",
  "ExportToGippity",
}

T["usercmds"]["markdown commands"] = new_set({
  hooks = {
    pre_once = function()
      -- Open a markdown buffer to trigger ftplugin
      child.cmd("edit /tmp/_test_usercmds.md")
      child.lua([[vim.wait(2000, function() return vim.bo.filetype == "markdown" end)]])
    end,
  },
  parametrize = (function()
    local p = {}
    for _, c in ipairs(md_cmds) do
      table.insert(p, { c })
    end
    return p
  end)(),
}, {
  test = function(name)
    expect.equality(cmd_exists(name), true)
  end,
})

return T
