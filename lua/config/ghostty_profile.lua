-- Which Ghostty profile-theme should this Neovim instance wear?
-- nil means: plain Ghostty, or any context where the catppuccin look must
-- win. Derived Ghostty bundles (GhosttyNu, GhosttyXonsh, ...) inject
-- GHOSTTY_NVIM_THEME per variant via their Ghostty config `env` key.
--
-- Every guard fails toward nil (catppuccin): a wrong answer here may only
-- ever make a derived profile look plain, never make plain Ghostty look
-- derived.
local M = {}

-- Pure core, unit-testable with a fake context (tests/test_profile_theme.lua).
---@param ctx { force: string?, env_theme: string?, tmux: string?, argv: string[], neovide: boolean? }
function M._theme(ctx)
  -- Test/debug override; "" forces plain.
  if ctx.force ~= nil then
    if ctx.force == "" then
      return nil
    end
    return ctx.force
  end
  if ctx.env_theme == nil or ctx.env_theme == "" then
    return nil
  end
  -- tmux servers freeze the environment of whichever app spawned them; a
  -- pane attached from plain Ghostty could carry a stale value. Never trust
  -- the variable under tmux.
  if ctx.tmux ~= nil then
    return nil
  end
  -- --headless has no UI to theme. NOTE: --embed must NOT be treated as
  -- "GUI" — since the TUI client/server split, every ordinary terminal
  -- session's server process carries --embed (empirically: v:argv of a
  -- plain `nvim file` session). GUI detection is therefore flag-based
  -- (neovide) rather than argv-based. nvim_list_uis() is useless here:
  -- it is empty during startup even for TUI sessions.
  for _, arg in ipairs(ctx.argv) do
    if arg == "--headless" then
      return nil
    end
  end
  if ctx.neovide then
    return nil
  end
  return ctx.env_theme
end

function M.theme()
  return M._theme({
    force = vim.g.ghostty_profile_theme_force,
    env_theme = vim.env.GHOSTTY_NVIM_THEME,
    tmux = vim.env.TMUX,
    argv = vim.v.argv,
    neovide = vim.g.neovide,
  })
end

return M
