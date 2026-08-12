local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["usercmds"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

-- ── global commands ────────────────────────────────────────────────────────
-- LeanRichTokens is global on purpose rather than a Lean-buffer command: its
-- `status` subcommand answers "which toolchain and which legend" and must work
-- before any .lean file has been opened, which is exactly when you want to ask.
-- LeanSetupInfo is global for the same reason: it is the pasteable half of
-- VS Code's `Troubleshooting: Show Setup Information` (parity audit #57), and
-- "why is Lean not working here" gets asked before a .lean file is open.
local global_cmds = { "CapRep", "TSInfo", "UvInit", "LeanRichTokens", "LeanSetupInfo" }

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
    expect.equality(H.cmd_exists(child, name), true)
  end,
})

-- ── markdown commands (need .md buffer) ────────────────────────────────────
local md_cmds = {
  "MarksmanEnsureConfig",
  "RemarkEnsureConfig",
  "MarkdownEnsureConfigs",
  "MathDelimsToDollars",
  "DelimToggle",
  "PauseFormatToggle",
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
    expect.equality(H.cmd_exists(child, name), true)
  end,
})

return T
