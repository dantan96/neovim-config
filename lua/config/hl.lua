-- Highlight-table conversion.
--
-- `nvim_get_hl` and `nvim_set_hl` do not speak the same shape, and the
-- difference is not cosmetic: `vim.api.keyset.get_hl_info.cterm` is a
-- `hl_info.cterm`, which carries `foreground`/`background`, whereas the
-- `cterm` that `nvim_set_hl` accepts is a `highlight_cterm`, which carries
-- attributes only. Feeding the former straight back is a hard error --
-- measured, not inferred:
--
--   vim.api.nvim_set_hl(0, "X", { cterm = { foreground = 12 } })
--   --> Invalid key: 'foreground'
--
-- In practice today it does not fire: a sweep of all 948 groups defined in
-- this config, plus groups built with `:highlight ctermfg=5 guifg=#111111`
-- and with `nvim_set_hl(..., { ctermfg = 3 })`, showed `nvim_get_hl`
-- returning cterm colours at the TOP level as `ctermfg`/`ctermbg` every
-- single time and never nesting them. So the round trip is lossless as
-- things stand.
--
-- It is still worth converting rather than trusting that. `restyle()` in
-- plugins/profile_theme.lua runs on every ColorScheme; a throw there leaves
-- the statusline half-painted, and "no colorscheme ships a nested cterm
-- colour" is a property of the themes installed today, not of the API. This
-- makes the bad shape unrepresentable instead of unobserved.

local M = {}

--- Re-key what `nvim_get_hl` returned so `nvim_set_hl` will take it.
---
--- Everything is carried over -- deliberately. `nvim_set_hl` REPLACES a
--- group wholesale, so anything dropped here is a highlight attribute
--- silently lost on the next repaint, and a partial definition renders
--- colourless rather than inheriting. Enumerating the fields we "care
--- about" would therefore rot the moment Neovim adds an attribute; only the
--- two keys that genuinely cannot cross are rewritten.
---
---@param info vim.api.keyset.get_hl_info as returned by nvim_get_hl
---@return vim.api.keyset.highlight spec accepted by nvim_set_hl
function M.to_set_spec(info)
  ---@type vim.api.keyset.highlight
  local spec = {}
  for k, v in pairs(info) do
    spec[k] = v
  end
  if type(info.cterm) == "table" then
    local attrs = {}
    for k, v in pairs(info.cterm) do
      if k == "foreground" then
        spec.ctermfg = v
      elseif k == "background" then
        spec.ctermbg = v
      else
        attrs[k] = v
      end
    end
    spec.cterm = attrs
  end
  return spec
end

--- Read a group and hand back a table ready to give straight back to
--- `nvim_set_hl` -- the save half of a save/restore.
---
--- `link` defaults to true, i.e. a linked group is captured AS a link, which
--- is what a faithful restore wants. Pass `link = false` to resolve through
--- the link and capture concrete colours instead -- what a caller wants when
--- it is about to merge attributes onto the result, since merging onto
--- `{ link = "X" }` would produce a spec whose link swallows the merge.
---@param name string
---@param opts? { ns?: integer, link?: boolean }
---@return vim.api.keyset.highlight
function M.snapshot(name, opts)
  opts = opts or {}
  local link = opts.link ~= false
  return M.to_set_spec(vim.api.nvim_get_hl(opts.ns or 0, { name = name, link = link }))
end

return M
