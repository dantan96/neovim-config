local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

-- Plain-Ghostty baseline: with GHOSTTY_NVIM_THEME absent (helpers scrub it),
-- the config must be byte-identical to the pre-profile-theme world. This set
-- is the tripwire for the `enabled` gate in lua/plugins/themes.lua — if that
-- condition ever inverts or leaks, these fail.
T["baseline (plain Ghostty)"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

T["baseline (plain Ghostty)"]["colorscheme is catppuccin"] = function()
  expect.equality(child.lua_get("vim.g.colors_name"), "catppuccin-mocha")
end

T["baseline (plain Ghostty)"]["detection returns nil"] = function()
  expect.equality(
    child.lua_get([[require("config.ghostty_profile").theme() == nil]]),
    true
  )
end

-- Snapshot of load-bearing hand-tuned highlights (color_overrides base,
-- highlight_overrides LineNrWrap). Hex values are the catppuccin-mocha
-- results pinned at gate-introduction time.
T["baseline (plain Ghostty)"]["custom base background survives"] = function()
  local bg = child.lua_get(
    [[string.format("#%06x", vim.api.nvim_get_hl(0, { name = "Normal" }).bg)]]
  )
  expect.equality(bg, "#151520")
end

T["baseline (plain Ghostty)"]["LineNrWrap override survives"] = function()
  local fg = child.lua_get(
    [[string.format("#%06x", vim.api.nvim_get_hl(0, { name = "LineNrWrap" }).fg)]]
  )
  expect.equality(fg, "#313244") -- catppuccin mocha surface0
end

-- Forced derived mode: catppuccin must stand down. (Recipe behavior itself
-- is covered by unit tests on lua/plugins/profile_theme.lua; child startup
-- here must not depend on network plugin installs.)
T["derived (forced)"] = new_set({
  hooks = {
    pre_once = function()
      local args = vim.deepcopy(H.child_args)
      table.insert(args, "--cmd")
      table.insert(args, [[let g:ghostty_profile_theme_force = 'vellum']])
      child.restart(args)
      child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
    end,
    post_once = function() child.stop() end,
  },
})

T["derived (forced)"]["catppuccin is not active"] = function()
  expect.no_equality(child.lua_get("vim.g.colors_name"), "catppuccin-mocha")
end

T["derived (forced)"]["detection returns the forced theme"] = function()
  expect.equality(
    child.lua_get([[require("config.ghostty_profile").theme()]]),
    "vellum"
  )
end

-- Guard checks: exercise the pure core with explicit contexts so each guard
-- is tested in isolation (the in-process runner is headless, so going
-- through M.theme() would trip the argv guard first and prove nothing).
local _theme = require("config.ghostty_profile")._theme
local TUI = { "nvim" } -- argv with neither --embed nor --headless

T["guards"] = new_set()

T["guards"]["happy path returns the theme"] = function()
  expect.equality(_theme({ env_theme = "vellum", argv = TUI }), "vellum")
end

T["guards"]["tmux forces plain"] = function()
  expect.equality(
    _theme({ env_theme = "vellum", tmux = "/tmp/t,1,0", argv = TUI }) == nil,
    true
  )
end

T["guards"]["headless forces plain"] = function()
  expect.equality(
    _theme({ env_theme = "vellum", argv = { "nvim", "--headless" } }) == nil,
    true
  )
end

T["guards"]["embed alone does NOT force plain (TUI servers are --embed)"] = function()
  expect.equality(
    _theme({ env_theme = "vellum", argv = { "nvim", "--embed", "file.lua" } }),
    "vellum"
  )
end

T["guards"]["neovide forces plain"] = function()
  expect.equality(
    _theme({ env_theme = "vellum", argv = TUI, neovide = true }) == nil,
    true
  )
end

T["guards"]["empty env reads as absent"] = function()
  expect.equality(_theme({ env_theme = "", argv = TUI }) == nil, true)
end

T["guards"]["force override beats guards"] = function()
  expect.equality(
    _theme({ force = "nu-glass", tmux = "/tmp/t,1,0", argv = { "nvim", "--headless" } }),
    "nu-glass"
  )
end

-- Recipe spec shape: import the plugin module under a forced theme and
-- assert what lazy would receive. No child, no network.
local function spec_for(force)
  local prev = vim.g.ghostty_profile_theme_force
  vim.g.ghostty_profile_theme_force = force
  package.loaded["plugins.profile_theme"] = nil
  local spec = require("plugins.profile_theme")
  package.loaded["plugins.profile_theme"] = nil
  vim.g.ghostty_profile_theme_force = prev
  return spec
end

T["recipes"] = new_set()

T["recipes"]["plain contributes nothing"] = function()
  expect.equality(next(spec_for("")) == nil, true)
end

T["recipes"]["vellum maps to flexoki-light"] = function()
  local spec = spec_for("vellum")
  expect.equality(spec[1], "kepano/flexoki-neovim")
  expect.equality(spec.name, "flexoki")
end

T["recipes"]["flexoki-dark maps to flexoki"] = function()
  expect.equality(spec_for("flexoki-dark")[1], "kepano/flexoki-neovim")
end

T["recipes"]["nu-glass maps to mini.base16 (ANSI mirror)"] = function()
  local spec = spec_for("nu-glass")
  expect.equality(spec[1], "echasnovski/mini.nvim")
  expect.equality(spec.name, "mini.nvim")
end

T["recipes"]["unknown theme contributes nothing"] = function()
  local notified = false
  local prev_notify = vim.notify
  vim.notify = function() notified = true end
  local spec = spec_for("no-such-theme")
  vim.notify = prev_notify
  expect.equality(next(spec) == nil, true)
  expect.equality(notified, true)
end

return T
