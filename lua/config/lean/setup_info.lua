-- lua/config/lean/setup_info.lua — the pasteable half of VS Code's
-- `Troubleshooting: Show Setup Information` (parity audit #57, #56).
--
-- It is the first thing anyone on Lean Zulip asks for, and it matters more on
-- this machine than on most: MIL runs under an **elan directory override** to
-- a locally built, never-pushed toolchain (`lean4-rich`), so every future
-- debugging session and every Zulip question opens with "which toolchain was
-- actually live, and was it the patched one?".
--
-- HALF OF THAT IS ALREADY ANSWERED and is not duplicated here.
-- `:LeanRichTokens status` reports the elan-resolved toolchain AND
-- cross-checks it against the wire (rich_tokens.lua:255-283, 426-439), which
-- is a better diagnostic than any static dump. What was missing is the
-- pasteable part: OS/arch/CPU/RAM, tool versions, project path, and the
-- installed-toolchain list, as one Markdown block.
--
-- ── WHY `:LeanSetupInfo` AND NOT A `:checkhealth lean` SECTION ────────────
-- The roadmap suggested extending checkhealth, on the grounds that
-- `health.lua:48-58` is where someone will look. That health file is
-- **lean.nvim's own** (`lua/lean/health.lua`), and `:checkhealth lean`
-- resolves its provider by name off the runtimepath — a second `lua/lean/`
-- tree in this config would be shadowing a plugin's module namespace to add a
-- section, which is a much bigger commitment than the feature warrants. The
-- actual requirement is *pasteable text on the clipboard*, and that is a
-- command's job. `:checkhealth lean` still works and still says what it said.
--
-- ── elan.state() ──────────────────────────────────────────────────────────
-- Called for the first time anywhere in this config. Verified live from a
-- pty-hosted TUI on MIL: it is synchronous, needs no plenary async context,
-- and reports the directory override *well* — the case the roadmap flagged as
-- the one that might force a fallback to parsing `elan show`:
--
--   toolchains.active_override.reason.OverrideDB = "<MIL path>"
--   toolchains.active_override.unresolved.Local.name = "lean4-rich"
--   toolchains.resolved_active.live.Ok = "lean4-rich"
--   toolchains.installed = [ 4 entries with path + resolved_name ]
--
-- So the fallback is not needed. `M.collect()` still tolerates its absence.
--
-- Split so the interesting half is pure: `M.markdown(info)` is a total
-- function from a table to a string and is tested with a fixture, no editor,
-- no elan, no network.

local M = {}

---Run a command and return its first line of output, or nil.
---@param cmd string[]
---@return string|nil
local function first_line(cmd)
  if vim.fn.executable(cmd[1]) == 0 then
    return nil
  end
  local ok, out = pcall(function()
    return vim.system(cmd, { text = true }):wait(5000)
  end)
  if not ok or out.code ~= 0 then
    return nil
  end
  local line = ((out.stdout or "") .. (out.stderr or "")):match("^[^\n]*")
  return line and vim.trim(line) ~= "" and vim.trim(line) or nil
end

---Pull an `Ok`-wrapped value out of elan's Rust-serde-shaped JSON.
---@param v any
---@return string|nil
local function ok_value(v)
  if type(v) == "string" then
    return v
  end
  if type(v) == "table" then
    if type(v.Ok) == "string" then
      return v.Ok
    end
    if type(v.live) == "table" or type(v.live) == "string" then
      return ok_value(v.live)
    end
    if type(v.cached) == "string" then
      return v.cached
    end
  end
end

---Flatten `elan.state()` into the four fields worth pasting.
---@param state table|nil as returned by require('elan').state()
---@return table { active=, override=, default=, installed= }
function M.elan_fields(state)
  local t = (state or {}).toolchains or {}
  local out = {
    active = ok_value(t.resolved_active),
    default = ok_value(t.default and t.default.resolved),
    installed = {},
    override = nil,
  }
  local ov = t.active_override
  if ov then
    local name = ov.unresolved
      and (
        (ov.unresolved.Local and ov.unresolved.Local.name)
        or (ov.unresolved.Remote and ov.unresolved.Remote.origin)
      )
    local reason = ov.reason
      and (
        (type(ov.reason) == "table" and (ov.reason.OverrideDB or ov.reason.ToolchainFile))
        or (type(ov.reason) == "string" and ov.reason)
      )
    out.override = { name = name, reason = reason }
  end
  for _, tc in ipairs(t.installed or {}) do
    table.insert(out.installed, tc.resolved_name or tc.path or "?")
  end
  return out
end

---Everything worth pasting, as data. Every field is optional: a missing
---binary or a missing elan yields nil, never an error.
---@param bufnr integer|nil
---@return table
function M.collect(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local uname = vim.uv.os_uname()
  local cpus = vim.uv.cpu_info() or {}

  local root
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "leanls" })) do
    root = client.root_dir
  end

  local elan_state
  local ok, elan = pcall(require, "elan")
  if ok and type(elan.state) == "function" then
    local got, state = pcall(elan.state)
    if got then
      elan_state = state
    end
  end

  local rich
  local rok, rich_tokens = pcall(require, "config.lean.rich_tokens")
  if rok and type(rich_tokens.report) == "function" then
    local got, report = pcall(rich_tokens.report, bufnr)
    rich = got and report or nil
  end

  return {
    nvim = tostring(vim.version()),
    os = ("%s %s (%s)"):format(uname.sysname, uname.release, uname.machine),
    cpu = cpus[1] and ("%s x%d"):format(cpus[1].model, #cpus) or nil,
    ram = ("%.1f GiB"):format(vim.uv.get_total_memory() / 1024 ^ 3),
    project = root,
    file = vim.api.nvim_buf_get_name(bufnr),
    tools = {
      curl = first_line({ "curl", "--version" }),
      git = first_line({ "git", "--version" }),
      elan = first_line({ "elan", "--version" }),
      lake = first_line({ "lake", "--version" }),
      lean = first_line({ "lean", "--version" }),
    },
    elan = M.elan_fields(elan_state),
    rich_tokens = rich and rich.mode or nil,
  }
end

---Render `info` as one Markdown block, ready to paste into Zulip.
---Pure: same table in, same string out.
---@param info table as returned by M.collect
---@return string
function M.markdown(info)
  local L = {}
  local function row(k, v)
    table.insert(L, ("| %s | %s |"):format(k, v == nil and "*(not found)*" or tostring(v)))
  end

  table.insert(L, "### Lean setup information")
  table.insert(L, "")
  table.insert(L, "| | |")
  table.insert(L, "|---|---|")
  row("OS", info.os)
  row("CPU", info.cpu)
  row("RAM", info.ram)
  row("Neovim", info.nvim)
  row("Project", info.project)
  row("File", info.file)
  table.insert(L, "")
  table.insert(L, "| Tool | Version |")
  table.insert(L, "|---|---|")
  for _, name in ipairs({ "curl", "git", "elan", "lake", "lean" }) do
    row(name, (info.tools or {})[name])
  end
  table.insert(L, "")
  table.insert(L, "| Toolchain | |")
  table.insert(L, "|---|---|")
  local e = info.elan or {}
  row("Active", e.active)
  if e.override then
    row(
      "Override",
      ("`%s` (%s)"):format(tostring(e.override.name), tostring(e.override.reason))
    )
  else
    row("Override", "*(none)*")
  end
  row("Default", e.default)
  row("Installed", #(e.installed or {}) > 0 and table.concat(e.installed, ", ") or nil)
  row("Rich tokens", info.rich_tokens)
  return table.concat(L, "\n")
end

---Show the block in a scratch buffer and put it on the clipboard.
function M.show()
  local text = M.markdown(M.collect())
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  -- Same shape as the cheatsheet float in after/ftplugin/lean.lua: Snacks
  -- already binds `q`, and markview renders the tables.
  pcall(function()
    require("markview.actions").attach(buf)
    vim.b[buf]._markview_on = true
  end)
  local ok = pcall(function()
    Snacks.win({
      buf = buf,
      width = 0.8,
      height = 0.7,
      border = "rounded",
      title = " Lean setup information — copied to the clipboard ",
      title_pos = "center",
      wo = { wrap = false, number = false, signcolumn = "no", conceallevel = 2 },
      bo = { bufhidden = "wipe" },
    })
  end)
  if not ok then
    vim.api.nvim_win_set_buf(0, buf)
  end
end

---Register `:LeanSetupInfo`. GLOBAL, like `:LeanRichTokens` and for the same
---reason: "why is Lean not working here" is asked before a .lean file opens.
function M.setup()
  vim.api.nvim_create_user_command("LeanSetupInfo", M.show, {
    desc = "Pasteable Markdown: OS, tools, toolchains, project (for Zulip)",
  })
end

return M
