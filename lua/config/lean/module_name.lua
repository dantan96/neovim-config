-- lua/config/lean/module_name.lua — a Lean file's dotted module name.
--
--   MIL/C05_Elementary_Number_Theory/S02_Induction_and_Recursion.lean
--     -> MIL.C05_Elementary_Number_Theory.S02_Induction_and_Recursion
--
-- VS Code ships this as `lean4.copyModuleName` on the editor-tab context menu
-- (parity audit row #10). It comes up twice a session in MIL: writing an
-- `import` line after jumping into a file to see where something lives, and
-- saying "I am in MIL.C05_….S02" in a Zulip question. Retyping a path with
-- dots is exactly the operation a human gets wrong.
--
-- WHY THIS IS NOT `path − root`, WHICH IS WHAT THE ROADMAP EXPECTED.
-- Measured in a pty-hosted TUI against MIL: `vim.lsp.get_clients{bufnr=0}[1]
-- .root_dir` is the MIL PROJECT ROOT for a mathlib buffer too --
--
--   .lake/packages/mathlib/Mathlib/Tactic/Ring.lean   root_dir=<MIL>
--
-- -- so the naive subtraction yields `.lake.packages.mathlib.Mathlib.Tactic
-- .Ring`. One Lean project is many Lake packages, and a package's module
-- namespace starts at the package directory, not at the workspace. Hence rule
-- 1 below, which the roadmap predicted might be needed and is.
--
-- Rule 2 exists for the same reason one level further out: `gd` into core Lean
-- lands under a toolchain, where the sources sit at `<toolchain>/src/lean/`
-- (checked on both leanprover--lean4---v4.33.0 and the local lean4-rich
-- build). Without it, jumping to `Init/Prelude.lean` and asking for the module
-- name would answer with an absolute-path-shaped string.
--
-- Pure resolver plus a thin command, like config.lean.book: everything
-- interesting is `M.of(path, root)`, which takes its inputs as arguments and
-- so is testable without an editor, a server or a filesystem.

local M = {}

---Longest suffix of `path` that lies under `dir`, or nil.
---`dir` is nil-tolerant on purpose: the three rules in M.of are tried in
---sequence and each supplier may legitimately have nothing to offer.
---@param path string
---@param dir string|nil
---@return string|nil
local function relative_to(path, dir)
  if dir == nil or dir == "" then
    return nil
  end
  dir = dir:gsub("/+$", "") .. "/"
  if path:sub(1, #dir) == dir then
    return path:sub(#dir + 1)
  end
end

---The Lake package directory containing `path`, if it is a fetched dependency.
---
---The LAST `.lake/packages/<pkg>/` on the path, not the first: a dependency
---may itself carry a `.lake/packages` tree, and the innermost one is the
---package the file actually belongs to.
---@param path string
---@return string|nil
local function package_dir(path)
  local last
  local from = 1
  while true do
    local s, e = path:find("/%.lake/packages/[^/]+/", from)
    if not s then
      break
    end
    last = path:sub(1, e - 1)
    from = s + 1
  end
  return last
end

---The source root of a toolchain, if `path` is inside one.
---@param path string
---@return string|nil
local function toolchain_src(path)
  for _, marker in ipairs({ "/src/lean/", "/lib/lean4/library/" }) do
    local s = path:find(marker, 1, true)
    if s then
      return path:sub(1, s + #marker - 2)
    end
  end
end

---Dotted module name for a Lean source file.
---@param path string absolute path to a .lean file
---@param root string|nil the LSP/project root, if one is known
---@return string|nil name  e.g. "Mathlib.Tactic.Ring"
---@return string|nil err   why nothing was resolved
function M.of(path, root)
  if path == nil or path == "" then
    return nil, "buffer has no file name"
  end
  if not path:match("%.lean$") then
    return nil, "not a .lean file"
  end

  -- Order matters: a dependency and a toolchain are both *inside* the project
  -- root as far as string prefixes are concerned, so the specific rules have
  -- to be tried before the general one.
  local rel = relative_to(path, package_dir(path))
    or relative_to(path, toolchain_src(path))
    or relative_to(path, root)
  if not rel then
    return nil, "not inside the project, a Lake package or a toolchain"
  end

  rel = rel:gsub("%.lean$", "")
  if rel == "" then
    return nil, "empty module name"
  end
  -- A leading or doubled separator would produce an empty component, which is
  -- not a legal Lean module name and is a sign the rules above missed.
  if rel:match("^/") or rel:find("//", 1, true) then
    return nil, "path has empty components"
  end
  return (rel:gsub("/", "."))
end

---The project root for a buffer: the language server's if one is attached,
---otherwise the nearest Lake project marker.
---@param bufnr integer
---@return string|nil
function M.root(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.root_dir then
      return client.root_dir
    end
  end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path ~= "" then
    return vim.fs.root(path, { "lakefile.toml", "lakefile.lean", "lean-toolchain" })
  end
end

---Put the current buffer's module name on the clipboard and the unnamed
---register, and echo it so it can be read off the screen too.
---
---Both registers, deliberately: `clipboard` is not set to `unnamedplus` in
---this config, so writing only `+` would leave `p` pasting something else.
function M.copy()
  local bufnr = vim.api.nvim_get_current_buf()
  local name, err = M.of(vim.api.nvim_buf_get_name(bufnr), M.root(bufnr))
  if not name then
    vim.notify("Lean module name: " .. err, vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", name)
  vim.fn.setreg('"', name)
  vim.notify(name, vim.log.levels.INFO, { title = "Copied module name" })
end

return M
