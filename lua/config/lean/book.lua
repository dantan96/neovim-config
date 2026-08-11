-- lua/config/lean/book.lua — open the rendered book page for a Lean file.
--
-- Written for Mathematics in Lean, whose repo ships a Sphinx build: one HTML
-- page per chapter directory, with an anchor per section.
--
--   MIL/C02_Basics/S03_Using_Theorems_and_Lemmas.lean
--     -> html/C02_Basics.html#using-theorems-and-lemmas
--
-- Solutions sit one level deeper (MIL/C02_Basics/solutions/Solutions_S03_*),
-- so the chapter is found by walking up to the first C<NN>_ directory rather
-- than by taking the parent.
--
-- The anchor is DERIVED from the filename but then CHECKED against the page,
-- because not every section file has a matching anchor: C06's
-- S03_Inductive_Structures and C08's S03_Subobjects have none, and the
-- per-chapter scratchpad.lean files are not sections at all. When the derived
-- anchor is absent we open the chapter page without one, rather than sending
-- the browser to a fragment that does not exist.
--
-- Checked over all 88 MIL Lean files: 82 anchor, 5 fall back to the chapter
-- page, and MIL/Common.lean correctly resolves to nothing (not a section).
--
-- Everything is guarded, so this is inert in a Lean project that has no
-- html/ directory (leanplay, mathlib4) instead of erroring.

local M = {}

---Walk up from a file to the first directory named like a chapter.
---@param path string
---@return string|nil name e.g. "C02_Basics"
local function chapter_name(path)
  local dir = vim.fs.dirname(path)
  while dir and dir ~= "/" and dir ~= "." do
    local name = vim.fs.basename(dir)
    if name:match("^C%d+_") then
      return name
    end
    dir = vim.fs.dirname(dir)
  end
end

---Slug Sphinx would have generated from a section filename.
---@param path string
---@return string|nil
local function derived_anchor(path)
  local base = vim.fn.fnamemodify(path, ":t:r")
  base = base:gsub("^Solutions_", ""):gsub("^S%d+_", "")
  if base == "" or base:match("^C%d+_") then
    return nil
  end
  return (base:gsub("_", "-"):lower())
end

---Resolve the book page for a Lean file.
---@param path string absolute path to a .lean file
---@return string|nil url  file:// URL, anchored when the anchor really exists
---@return string|nil err  why nothing was resolved
function M.target(path)
  if path == nil or path == "" then
    return nil, "buffer has no file name"
  end
  local root = vim.fs.root(path, { "lakefile.toml", "lakefile.lean", "lean-toolchain" })
  if not root then
    return nil, "not inside a Lean project"
  end
  local chapter = chapter_name(path)
  if not chapter then
    return nil, "no chapter directory (expected a C<NN>_* ancestor)"
  end
  local html = vim.fs.joinpath(root, "html", chapter .. ".html")
  if not vim.uv.fs_stat(html) then
    return nil, "no rendered page at " .. vim.fn.fnamemodify(html, ":~:.")
  end

  local url = vim.uri_from_fname(html)
  local anchor = derived_anchor(path)
  if anchor then
    local ok, lines = pcall(vim.fn.readfile, html)
    if ok and table.concat(lines, "\n"):find('id="' .. anchor .. '"', 1, true) then
      url = url .. "#" .. anchor
    end
  end
  return url
end

---Open the book page for the current buffer in the default browser.
function M.open()
  local url, err = M.target(vim.api.nvim_buf_get_name(0))
  if not url then
    vim.notify("Lean book: " .. err, vim.log.levels.WARN)
    return
  end
  vim.ui.open(url)
end

return M
