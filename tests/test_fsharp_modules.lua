-- tests/test_fsharp_modules.lua — the config.fsharp.* module split.
--
-- Guards the refactor of after/ftplugin/fsharp.lua: commands and
-- buffer-local keymaps must exist for EVERY F# buffer (including a
-- re-:edit of the same file — they used to live inside a "not already
-- LSP-attached" branch and could be skipped), setup() must be
-- idempotent, and the constraint overlay must actually paint.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

local tmp_dir, fs_path

T["fsharp modules"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      fs_path = tmp_dir .. "/module_probe.fs"
      vim.fn.writefile({
        "let inline f<'T when 'T : comparison> (x: 'T) = x",
        "let g lst =",
        "    match lst with",
        "    | h :: t -> t",
        "    | [] -> []",
      }, fs_path)
      child.lua(string.format("vim.cmd.edit(%q)", fs_path))
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

local commands = {
  { "FsiSend" },
  { "FsiShow" },
  { "FsiStatus" },
  { "FsiSelfTest" },
  { "FsiOpenLog" },
  { "FSharpEnsureEditorConfig" },
  { "FSharpSplitterLog" },
}

T["fsharp modules"]["commands registered"] = new_set({
  parametrize = commands,
}, {
  test = function(name)
    expect.equality(H.cmd_exists(child, name), true)
  end,
})

local function buf_has_map(mode, lhs)
  return child.lua_get(string.format(
    [[(function()
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, %q)) do
        if m.lhs:lower() == (%q):lower() then return true end
      end
      return false
    end)()]],
    mode,
    lhs
  ))
end

T["fsharp modules"]["buffer keymaps present"] = function()
  expect.equality(buf_has_map("n", "<M-CR>"), true)
  expect.equality(buf_has_map("x", "<M-CR>"), true)
  expect.equality(buf_has_map("n", "<M-@>"), true)
end

T["fsharp modules"]["buffer command present"] = function()
  local has = child.lua_get([[(function()
    for name in pairs(vim.api.nvim_buf_get_commands(0, {})) do
      if name == "FSharpSplitStrings" then return true end
    end
    return false
  end)()]])
  expect.equality(has, true)
end

T["fsharp modules"]["keymaps survive re-edit of the buffer"] = function()
  -- Regression: with the maps inside the LSP not-already-attached
  -- branch, a re-sourced ftplugin (e.g. :edit) could skip them.
  child.lua([[vim.cmd.edit({ bang = true })]])
  expect.equality(buf_has_map("n", "<M-CR>"), true)
  expect.equality(buf_has_map("n", "<M-@>"), true)
end

T["fsharp modules"]["setup is idempotent"] = function()
  local counts = child.lua_get([[(function()
    local function n(group)
      local ok, cmds = pcall(vim.api.nvim_get_autocmds, { group = group })
      return ok and #cmds or -1
    end
    local before = {
      refresh = n("fs_constraint_names_refresh"),
      colors = n("fs_constraint_names_colors"),
      hl = n("fs_hl_reapply"),
      du = n("fs_du_binder_refs"),
    }
    -- Re-run every setup; once-guards must make these no-ops.
    require("config.fsharp.highlights").setup()
    require("config.fsharp.constraints").setup()
    require("config.fsharp.du_refs").setup()
    require("config.fsharp.fsi").setup()
    require("config.fsharp.editorconfig").setup()
    require("config.fsharp.splitter").setup()
    local after = {
      refresh = n("fs_constraint_names_refresh"),
      colors = n("fs_constraint_names_colors"),
      hl = n("fs_hl_reapply"),
      du = n("fs_du_binder_refs"),
    }
    return { before = before, after = after }
  end)()]])
  expect.equality(counts.before, counts.after)
end

T["fsharp modules"]["constraint overlay paints extmarks"] = function()
  local marks = child.lua_get(string.format(
    [[(function()
      vim.cmd.edit(%q)
      require("config.fsharp.constraints").refresh(0)
      local ns = vim.api.nvim_create_namespace("fs_constraint_names")
      return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
    end)()]],
    fs_path
  ))
  -- "comparison" in the constraint clause must be highlighted.
  expect.equality(marks > 0, true)
end

T["fsharp modules"]["FsharpConstraint survives colorscheme reload"] = function()
  -- :colorscheme clears user-defined groups; with setup() once-guarded
  -- there is no per-buffer re-source to heal FsharpConstraint, so the
  -- ColorScheme handler must re-apply it (regression: it only repainted
  -- extmarks, leaving them on an empty group).
  local fg = child.lua_get([[(function()
    vim.cmd.colorscheme("catppuccin")
    return vim.api.nvim_get_hl(0, { name = "FsharpConstraint", link = false }).fg
  end)()]])
  expect.equality(fg, 16711935) -- 0xff00ff
end

T["fsharp modules"]["cons hl group defined pink"] = function()
  local fg = child.lua_get(
    [[vim.api.nvim_get_hl(0, { name = "@operator.cons.fsharp", link = false }).fg]]
  )
  expect.equality(fg, 16106215) -- 0xf5c2e7
end

return T
