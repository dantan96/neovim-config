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
--   * $LEAN_NVIM_FORK_DIR overrides the path, so the missing-fork branch can
--     actually be exercised rather than reasoned about.
--
-- WHAT HAPPENS WHEN THE FORK IS MISSING, and why it is not a quiet fallback.
-- It used to be one: config.lean.upstream_fixes silently reapplied three
-- wrappers and the session carried on looking normal on plain upstream
-- lean.nvim. That is the exact failure this project keeps being bitten by --
-- something degrades and looks fine -- and it is worse here than elsewhere,
-- because the fork is gitignored, never pushed, and the sibling Lean fork's
-- build directory was already clobbered once by a stray build.
--
-- So a missing fork is now LOUD: an error notification naming the path, every
-- session, until it is fixed. The three fixes live in the fork and nowhere
-- else. If you see that message, restore the fork from
-- ~/ClaudeProjects/leanSetup-lean-nvim-fork-backup.bundle:
--
--     git clone ~/ClaudeProjects/leanSetup-lean-nvim-fork-backup.bundle \
--       ~/ClaudeProjects/leanSetup/lean-nvim-rich -b dan/rich-infoview

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

---Complain, once per session, if the fork is not there. Called from
---lua/plugins/lean.lua's `config`. Deliberately `vim.notify` at ERROR rather
---than a silent fallback: without the fork this is plain upstream lean.nvim,
---missing the Loogle crash guard, the telescope finder fix, the satellite
---handler fix and parity items 7-9 -- and every one of those is invisible
---until you happen to trip over it.
local warned = false
function M.warn_if_missing()
  if warned or M.enabled() then
    return false
  end
  warned = true
  vim.notify(
    ("lean.nvim fork NOT found at %s\n"):format(M.dir())
      .. "Running plain upstream lean.nvim: no Loogle crash guard, no telescope\n"
      .. "finder fix, no satellite handler fix, and no parity items 7-9.\n"
      .. "Restore it from ~/ClaudeProjects/leanSetup-lean-nvim-fork-backup.bundle",
    vim.log.levels.ERROR,
    { title = "Lean" }
  )
  return true
end

return M
