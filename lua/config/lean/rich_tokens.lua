-- lua/config/lean/rich_tokens.lua — one switch for the patched Lean server's
-- rich semantic-token legend, and one command that tells the truth about it.
--
-- TWO TOOLCHAINS EXIST ON THIS MACHINE and the config must be correct under
-- either:
--
--   * leanprover/lean4:v4.30.0 — stock. Its legend is the LSP standard set
--     plus upstream's `leanSorryLike`.
--   * lean4-rich — a local build (~/ClaudeProjects/leanSetup/lean4-rich-tokens)
--     whose server adds the token types `theorem`, `axiom`, `opaque`,
--     `recursor`, `tactic` and 31 modifiers, among them `propWorld`,
--     `dataWorld`, `polyWorld` and `element`, `sort`, `former`.
--
-- `lean --version` CANNOT TELL THEM APART: the patched build sits on stock
-- v4.30.0's commit (both report `d024af0996…`), so the version string differs
-- only in the host triple of the machine that built it. `elan show` names the
-- active toolchain; that is what `:LeanRichTokens status` reports.
--
-- ── why detection, not a flag ─────────────────────────────────────────────
-- The patched server GATES the rich legend on the client capability
-- `experimental.leanRichTokens` (that is the whole point of the gate: a client
-- that has not asked keeps receiving the stock legend). So the negotiation is
-- two-sided, and the client can simply LOOK at what came back:
--
--   client.server_capabilities.semanticTokensProvider.legend.tokenModifiers
--
-- If that array contains `propWorld`, the server is patched AND agreed to send
-- the rich stream. No flag to remember, and no way for the answer to drift
-- from reality — it IS reality, read off the wire.
--
-- `propWorld` is the marker rather than a token TYPE because the type list is
-- the more likely thing to gain a standard LSP name upstream; the world axis
-- is unambiguously this branch's invention.
--
-- ── the override ──────────────────────────────────────────────────────────
--   vim.g.lean_rich_tokens = nil    detect (default)
--   vim.g.lean_rich_tokens = false  force standard, even against a patched
--                                   server — so the two can be compared
--   vim.g.lean_rich_tokens = true   force rich, and complain if the legend
--                                   that came back does not actually carry the
--                                   names (which means the toolchain is stock,
--                                   not that the setting is wrong)
--
-- Forcing standard is not cosmetic and not client-side: it withholds the
-- capability, so the patched server itself falls back to the stock legend. The
-- rich highlight groups in lua/plugins/themes.lua then match nothing and are
-- inert, which is why no group has to be undefined to switch modes.
--
-- ── what this module does NOT control ─────────────────────────────────────
-- Highlight-group definitions. Those are lua/plugins/themes.lua's, they are
-- keyed by names the server may or may not send, and a group naming a token
-- that never arrives is dead rather than wrong. Mode switching leaves them
-- alone in both directions.
--
-- ── mode vs toolchain ─────────────────────────────────────────────────────
-- These are different axes and `status` prints both because they can disagree:
--
--   MODE      is renegotiated by restarting the language server, which
--             `:LeanRichTokens on|off|toggle` does for you when the running
--             client's legend no longer matches what you asked for.
--   TOOLCHAIN is chosen by elan — a directory override, a `lean-toolchain`
--             file or $ELAN_TOOLCHAIN — and no editor command can change it.
--             Forcing rich mode against a stock toolchain gets you a warning
--             and the stock legend, because there is nothing else to get.

local M = {}

-- The one legend name that only the patched server sends. See the header for
-- why a modifier and why this one.
M.MARKER = "propWorld"

M.SERVER = "leanls"

--- The last diagnosis, so `status` and the tests can read structured state
--- rather than scraping `:messages`. Absence of a warning is otherwise very
--- hard to assert on.
---@class LeanRichTokensReport
---@field override boolean|nil what vim.g.lean_rich_tokens said
---@field legend_rich boolean|nil nil when no client was attached to ask
---@field mode string "rich" | "standard" | "unknown"
---@field warned boolean whether the mismatch warning fired
---@field client_id integer|nil
M.last = {
  override = nil,
  legend_rich = nil,
  mode = "unknown",
  warned = false,
  client_id = nil,
}

-- Clients already complained about, so re-attaching a buffer does not re-warn.
local warned_clients = {}

--- vim.g.lean_rich_tokens, normalised. Vimscript-set globals arrive as 0/1.
---@return boolean|nil nil means "detect"
function M.override()
  local v = vim.g.lean_rich_tokens
  if v == nil then
    return nil
  end
  if v == 0 or v == false then
    return false
  end
  return true
end

--- Should `experimental.leanRichTokens` go on the wire?
---
--- True in BOTH the auto and the forced-on case: detection is only possible if
--- we ask, since the patched server withholds the rich legend from a client
--- that did not. Only an explicit `false` withholds the capability.
---@return boolean
function M.advertise()
  return M.override() ~= false
end

--- Attached leanls clients (all of them; a session can have one per project).
---@param bufnr integer|nil restrict to a buffer
---@return vim.lsp.Client[]
function M.clients(bufnr)
  return vim.lsp.get_clients({ name = M.SERVER, bufnr = bufnr })
end

--- The semantic-token legend a client negotiated, or nil if it has none.
---@param client vim.lsp.Client
---@return { tokenTypes: string[], tokenModifiers: string[] }|nil
function M.legend(client)
  return vim.tbl_get(client, "server_capabilities", "semanticTokensProvider", "legend")
end

--- Does this client's legend carry the patched names?
---@param client vim.lsp.Client
---@return boolean|nil nil when the client advertises no legend at all
function M.legend_is_rich(client)
  local legend = M.legend(client)
  if not legend or not legend.tokenModifiers then
    return nil
  end
  return vim.tbl_contains(legend.tokenModifiers, M.MARKER)
end

--- The effective mode: does rich-token client behaviour run for this buffer?
---
--- A forced-off setting wins outright. Otherwise the legend decides — including
--- under a forced-ON setting, because wanting the rich stream does not conjure
--- it out of a stock server, and pretending otherwise would make every consumer
--- of this function wrong at once.
---@param bufnr integer|nil
---@return boolean
function M.enabled(bufnr)
  if M.override() == false then
    return false
  end
  for _, client in ipairs(M.clients(bufnr)) do
    if M.legend_is_rich(client) then
      return true
    end
  end
  return false
end

--- Look at a client, record what was found, warn on the one case that deserves
--- it: the user asked for rich and the wire does not have it.
---@param client vim.lsp.Client
---@return LeanRichTokensReport
function M.diagnose(client)
  local override = M.override()
  local rich = client and M.legend_is_rich(client) or nil
  local warned = false

  if override == true and rich == false then
    if not warned_clients[client.id] then
      warned_clients[client.id] = true
      warned = true
      vim.notify(
        ("vim.g.lean_rich_tokens = true, but %s's legend has no `%s`.\n"):format(M.SERVER, M.MARKER)
          .. "This project is on a stock Lean toolchain; the rich token stream\n"
          .. "does not exist to be turned on. `:LeanRichTokens status` shows which\n"
          .. "toolchain elan resolved. Highlighting is unaffected — the rich groups\n"
          .. "simply match nothing.",
        vim.log.levels.WARN,
        { title = "LeanRichTokens" }
      )
    else
      warned = true -- already said once for this client; still a mismatch
    end
  end

  M.last = {
    override = override,
    legend_rich = rich,
    mode = (override == false or rich == false) and "standard"
      or (rich == true) and "rich"
      or "unknown",
    warned = warned,
    client_id = client and client.id or nil,
  }
  return M.last
end

-- ── toolchain, straight from elan ─────────────────────────────────────────
-- Deliberately shelling out rather than reading `lean-toolchain`: that file is
-- only one of the four things elan consults (directory override, $ELAN_TOOLCHAIN
-- and the default are the others), and the whole value of `status` is that it
-- reports what actually happened.

--- @param cwd string|nil directory to resolve the toolchain in
--- @return string toolchain name, or a message saying why it is unknown
function M.toolchain(cwd)
  if vim.fn.executable("elan") == 0 then
    return "unknown (elan not on PATH)"
  end
  local out = vim.system({ "elan", "show" }, {
    cwd = cwd and vim.uv.fs_stat(cwd) and cwd or nil,
    env = { ELAN_NO_OVERRIDE_NOTICE = "1" },
    text = true,
  }):wait(5000)
  if out.code ~= 0 then
    return ("unknown (elan show exited %d)"):format(out.code)
  end
  -- The line after the `----` rule under "active toolchain", which carries the
  -- override reason in parentheses when there is one.
  local active = (out.stdout or ""):match("active toolchain%s*\n%-+%s*\n%s*([^\n]+)")
  return active and vim.trim(active) or "unknown (unrecognised `elan show` output)"
end

-- ── status ────────────────────────────────────────────────────────────────

--- Everything `:LeanRichTokens status` knows, as data.
---@param bufnr integer|nil
---@return table
function M.report(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = M.clients(bufnr)
  if #clients == 0 then
    clients = M.clients() -- any project's, so status works from a non-Lean buffer
  end
  local client = clients[1]
  local legend = client and M.legend(client)
  local root = client and (client.root_dir or client.config.root_dir) or vim.uv.cwd()

  return {
    override = M.override(),
    advertised = M.advertise(),
    client = client and { id = client.id, root_dir = root } or nil,
    legend_rich = client and M.legend_is_rich(client) or nil,
    n_types = legend and legend.tokenTypes and #legend.tokenTypes or nil,
    n_mods = legend and legend.tokenModifiers and #legend.tokenModifiers or nil,
    marker = legend
        and legend.tokenModifiers
        and vim.tbl_contains(legend.tokenModifiers, M.MARKER)
      or false,
    mode = M.enabled(bufnr) and "rich" or "standard",
    toolchain = M.toolchain(root),
    last = vim.deepcopy(M.last),
  }
end

---@param bufnr integer|nil
---@return string[]
function M.status_lines(bufnr)
  local r = M.report(bufnr)
  local function yn(v)
    if v == nil then
      return "unknown"
    end
    return v and "yes" or "no"
  end

  local requested = r.override == nil and "auto (detect from the legend)"
    or r.override and "forced on  (vim.g.lean_rich_tokens = true)"
    or "forced off (vim.g.lean_rich_tokens = false)"

  local lines = {
    "LeanRichTokens",
    "  mode in effect  : " .. r.mode,
    "  requested       : " .. requested,
    "",
    "  ── toolchain (elan decides; no editor command changes this) ──",
    "  active toolchain: " .. r.toolchain,
    "  project root    : " .. tostring(r.client and r.client.root_dir or vim.uv.cwd()),
  }

  vim.list_extend(lines, {
    "",
    "  ── legend (the server decides, at initialize) ──",
  })
  if not r.client then
    vim.list_extend(lines, {
      "  no leanls client attached — nothing has been negotiated yet.",
      "  capability that WOULD be advertised: experimental.leanRichTokens = "
        .. tostring(r.advertised),
    })
  else
    vim.list_extend(lines, {
      ("  client id       : %d"):format(r.client.id),
      "  capability sent : experimental.leanRichTokens = " .. tostring(r.advertised),
      ("  legend size     : %d token types, %d modifiers"):format(r.n_types or 0, r.n_mods or 0),
      "  has `" .. M.MARKER .. "`  : " .. yn(r.marker),
    })
    -- The disagreement worth surfacing: elan gave you the patched toolchain and
    -- the legend still came back stock, or the reverse.
    if r.toolchain:match("^lean4%-rich") and r.marker == false then
      vim.list_extend(lines, {
        "",
        "  NOTE the patched toolchain is active but the legend is stock — the",
        "       capability was withheld. Restart the server after turning the",
        "       mode on: `:LeanRichTokens on`.",
      })
    elseif not r.toolchain:match("^lean4%-rich") and r.marker then
      vim.list_extend(lines, {
        "",
        "  NOTE the legend is rich but elan does not name the patched toolchain;",
        "       the running server predates the current override.",
      })
    end
  end

  vim.list_extend(lines, {
    "",
    "  Changing MODE      : :LeanRichTokens on|off|toggle (restarts leanls when",
    "                       the running legend disagrees).",
    "  Changing TOOLCHAIN : elan override set <toolchain> (or $ELAN_TOOLCHAIN),",
    "                       then restart Neovim's leanls. Different thing.",
  })
  return lines
end

-- ── switching ─────────────────────────────────────────────────────────────

--- Re-request semantic tokens for every attached Lean buffer, so a mode change
--- is visible without touching the file.
local function refresh_tokens()
  for _, client in ipairs(M.clients()) do
    for bufnr in pairs(client.attached_buffers or {}) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        pcall(vim.lsp.semantic_tokens.force_refresh, bufnr)
      end
    end
  end
end

--- Stop and restart leanls so the capability is renegotiated.
---
--- `vim.lsp.enable(name, false)` stops the running clients AND drops the
--- resolved config, so the re-enable re-runs every `lsp/leanls.lua` on the
--- runtimepath — including after/lsp/leanls.lua, which reads
--- `vim.g.lean_rich_tokens` fresh. That is the whole reason this works without
--- restarting Neovim: config resolution is cached (`_enabled_configs[name]
--- .resolved_config`) and disabling is what invalidates the cache.
---@return boolean restarted
local function restart_server()
  if #M.clients() == 0 then
    return false
  end
  warned_clients = {}
  vim.lsp.enable(M.SERVER, false)
  vim.wait(5000, function()
    return #M.clients() == 0
  end, 50)
  vim.lsp.enable(M.SERVER, true)
  return true
end

--- Set the mode and make it real.
---@param mode "on"|"off"|"auto"
---@return string message
function M.set(mode)
  if mode == "auto" then
    vim.g.lean_rich_tokens = nil
  else
    vim.g.lean_rich_tokens = (mode == "on")
  end

  -- Bust the cached config even when nothing is running, so a client started
  -- later by lean.nvim sees the new capability set.
  pcall(vim.lsp.config, M.SERVER, {})

  -- Only restart when the wire actually disagrees with what was asked for.
  -- Restarting leanls on a mathlib project costs a re-elaboration, so it is
  -- not something to do for a no-op.
  local want = M.advertise()
  local disagrees = false
  for _, client in ipairs(M.clients()) do
    local rich = M.legend_is_rich(client)
    if rich ~= nil and rich ~= want then
      disagrees = true
    end
  end

  local msg
  if disagrees and restart_server() then
    msg = ("LeanRichTokens: %s — restarted %s to renegotiate the legend."):format(mode, M.SERVER)
  else
    refresh_tokens()
    msg = ("LeanRichTokens: %s — legend already matches; re-requested tokens."):format(mode)
    if #M.clients() == 0 then
      msg = ("LeanRichTokens: %s — no %s running; takes effect when one starts."):format(
        mode,
        M.SERVER
      )
    end
  end
  return msg
end

-- ── wiring ────────────────────────────────────────────────────────────────

--- Create the command and the attach hook. Called from plugins/lean.lua's
--- `init`, i.e. at startup and before lean.nvim loads, so `:LeanRichTokens
--- status` answers from any buffer rather than only from a Lean one.
function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LeanRichTokens", { clear = true }),
    desc = "diagnose the Lean semantic-token legend once per client",
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= M.SERVER then
        return
      end
      -- Deferred: the warning is a user-visible notify and LspAttach runs
      -- inside the client's initialize handling.
      vim.schedule(function()
        if not client.is_stopped or not client:is_stopped() then
          M.diagnose(client)
        end
      end)
    end,
  })

  vim.api.nvim_create_user_command("LeanRichTokens", function(opts)
    local arg = opts.args ~= "" and opts.args or "status"
    if arg == "status" then
      vim.notify(table.concat(M.status_lines(), "\n"), vim.log.levels.INFO)
    elseif arg == "on" or arg == "off" or arg == "auto" then
      vim.notify(M.set(arg), vim.log.levels.INFO)
    elseif arg == "toggle" then
      -- From auto, toggling means "the opposite of what is happening now",
      -- which is the only reading that does something visible.
      vim.notify(M.set(M.enabled() and "off" or "on"), vim.log.levels.INFO)
    else
      vim.notify(
        "LeanRichTokens: expected on|off|toggle|auto|status, got " .. arg,
        vim.log.levels.ERROR
      )
    end
  end, {
    nargs = "?",
    desc = "Lean rich semantic tokens: on|off|toggle|auto|status",
    complete = function()
      return { "on", "off", "toggle", "auto", "status" }
    end,
  })
end

return M
