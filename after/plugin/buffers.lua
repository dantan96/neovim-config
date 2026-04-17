-- after/plugin/buffers.lua

-- Check if a mapping already exists (buffer-local or global) WITHOUT vim.keymap.get
local function has_map(mode, lhs, bufnr)
  bufnr = bufnr or 0
  -- 1) buffer-local
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if m.lhs == lhs then
      return true
    end
  end
  -- 2) global
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if m.lhs == lhs then
      return true
    end
  end
  return false
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
