-- lua/config/lean/infoview_hl.lua — give the Lean infoview its own background.
--
-- The infoview is a normal split, so by default it is the same colour as the
-- code pane next to it and the eye has to find the border to tell them apart.
-- This tints it.
--
-- WHY A WINDOW HIGHLIGHT NAMESPACE, not 'winhighlight': lean.nvim owns that
-- option. Infoview:__update_winhighlight (infoview.lua:895) rewrites it on
-- every pin update, LSP death and imports-out-of-date transition, and the
-- normal case sets it to '', so anything written there is erased within a
-- keystroke or two. nvim_win_set_hl_ns is a separate mechanism lean.nvim never
-- touches, and the two compose: when lean.nvim maps NormalNC:leanInfoPaused to
-- grey out a paused view, that still wins over the namespace's NormalNC.
--
-- The colour is DERIVED from the active colorscheme rather than hard-coded, so
-- it survives a theme switch and still works under the derived Ghostty
-- profiles, where lua/plugins/themes.lua stands down entirely.

local M = {}

-- How far to pull the background toward the accent colour. 0.12 is about the
-- smallest value that is unmistakable on a dark theme without the pane reading
-- as a highlighted region.
local TINT = 0.12

local ns = vim.api.nvim_create_namespace("lean.infoview.bg")

---@param bg integer 24-bit colour
---@param fg integer 24-bit colour
---@param alpha number how much of `fg` to mix in, 0..1
---@return integer
local function blend(bg, fg, alpha)
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local b = math.floor(bg / 2 ^ shift) % 256
    local f = math.floor(fg / 2 ^ shift) % 256
    out = out * 256 + math.min(255, math.floor(b * (1 - alpha) + f * alpha + 0.5))
  end
  return out
end

---(Re)compute LeanInfoviewNormal and load it into the namespace.
function M.refresh()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  -- A transparent colorscheme has no Normal bg to tint; leave it alone rather
  -- than inventing one and breaking the terminal's own background.
  if not normal.bg then
    return
  end
  -- Function is blue-ish in essentially every scheme, so the tint reads as a
  -- cool panel. Normal fg is the fallback: a plain lift, never a no-op.
  local accent = vim.api.nvim_get_hl(0, { name = "Function", link = false }).fg
    or normal.fg
    or normal.bg
  local bg = blend(normal.bg, accent, TINT)

  vim.api.nvim_set_hl(0, "LeanInfoviewNormal", { bg = bg })
  vim.api.nvim_set_hl(ns, "Normal", { link = "LeanInfoviewNormal" })
  vim.api.nvim_set_hl(ns, "NormalNC", { link = "LeanInfoviewNormal" })
  -- EndOfBuffer is the run of `~` below the goal text — a large part of the
  -- pane when the goal is short. Its bg must be carried over explicitly,
  -- because most schemes define the group with a bg of their own.
  local eob = vim.api.nvim_get_hl(0, { name = "EndOfBuffer", link = false })
  vim.api.nvim_set_hl(ns, "EndOfBuffer", { fg = eob.fg, bg = bg })
end

---Point every window showing `buf` at the namespace.
---@param buf integer
function M.attach(buf)
  -- Deferred for the same reason lean.nvim defers winfixbuf in its own
  -- ftplugin/leaninfo.lua: at FileType time the infoview window is still being
  -- set up, and on a vertical infoview the buffer is briefly in two windows.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      pcall(vim.api.nvim_win_set_hl_ns, win, ns)
    end
  end)
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LeanInfoviewHighlight", { clear = true }),
  desc = "Re-derive the Lean infoview background from the new colorscheme",
  callback = M.refresh,
})
M.refresh()

return M
