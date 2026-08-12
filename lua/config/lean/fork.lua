-- lua/config/lean/fork.lua — where lean.nvim is loaded from, and whether the
-- local fork is in play.
--
-- This machine runs a permanently local fork of lean.nvim
-- (~/ClaudeProjects/leanSetup/lean-nvim-rich, branch dan/rich-infoview, cut
-- from upstream 3d8027a). It is never pushed and exists nowhere else. See
-- leanSetup/docs/lean-highlighting/decisions.md D15 and the fork's own
-- FORK-CHANGES.md.
--
-- ~/.config/nvim is a chezmoi external and the same tree is checked out on
-- WorkBox and main, where that directory does not exist. So the pin must be
-- conditional, and everything that depends on "are we on the fork?" must ask
-- here rather than re-deriving a path.
--
-- Two deliberate details:
--
--   * The existence test stats lua/lean/init.lua, not the directory. A
--     directory stat also succeeds for an empty leftover directory, or one
--     holding nothing but .git — both of which would pin lazy.nvim at a tree
--     with no plugin in it and break Lean support outright, on the machine
--     where it matters most.
--
--   * $LEAN_NVIM_FORK_DIR overrides the path. That exists so the fallback
--     branch can actually be tested (point it at a nonexistent path and the
--     config must come up on upstream lean.nvim with the three compatibility
--     fixes reapplied from config.lean.upstream_fixes) rather than being
--     reasoned about and discovered to be broken months later on another
--     machine. tests/test_lean.lua exercises exactly that.

local M = {}

---Default location of the fork on this machine.
local DEFAULT_DIR = "~/ClaudeProjects/leanSetup/lean-nvim-rich"

---Absolute path the fork would live at, expanded. Says nothing about whether
---it is there; use `enabled()` for that.
---@return string
function M.dir()
  local override = vim.env.LEAN_NVIM_FORK_DIR
  if override == nil or override == "" then
    override = DEFAULT_DIR
  end
  return vim.fn.expand(override)
end

---Is the fork present and usable on this machine?
---@return boolean
function M.enabled()
  return vim.uv.fs_stat(M.dir() .. "/lua/lean/init.lua") ~= nil
end

return M
