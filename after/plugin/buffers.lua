-- after/plugin/buffers.lua

-- Check if a mapping already exists (buffer-local or global).
-- NOTE: nvim_get_keymap returns lhs with <leader> already EXPANDED
-- (e.g. " B"), so a literal comparison against "<leader>B" never
-- matches. maparg() does its own expansion of the queried lhs and
-- checks both buffer-local and global maps.
local function has_map(mode, lhs)
  return vim.fn.maparg(lhs, mode) ~= ""
end

-- Safe mapping: skip & warn if something already mapped there
local function safe_map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend("keep", opts or {}, { noremap = true, silent = true })
  if has_map(mode, lhs) then
    vim.notify(
      string.format("Keymap %s %s already exists; skipping", mode, lhs),
      vim.log.levels.WARN
    )
    return
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- 1) New empty buffer in the SAME window (canonical)
-- :enew opens an unnamed buffer in the current window.
safe_map("n", "<leader>B", ":enew<CR>", { desc = "New empty buffer" }) -- help: :h :enew

-- 2) Copy CURRENT window to a NEW TAB (full window view; original splits remain)
-- :tab split creates a new tabpage with a copy of the current window.
safe_map(
  "n",
  "<leader>tt",
  ":tab split<CR>",
  { desc = "Copy window to new tab" }
) -- :h tabpage

-- 3) Buffer navigation (standard Ex commands)
safe_map("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" }) -- :h :bnext
safe_map("n", "<leader>bp", ":bprevious<CR>", { desc = "Prev buffer" }) -- :h :bprevious
safe_map("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" }) -- :h :bdelete
