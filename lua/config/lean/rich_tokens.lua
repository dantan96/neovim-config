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
-- The legend arrives at initialize and the client can simply LOOK at it:
--
--   client.server_capabilities.semanticTokensProvider.legend.tokenModifiers
--
-- If that array contains `propWorld`, the server is patched. No flag to
-- remember, and no way for the answer to drift from the truth — it IS the
-- truth, read off the wire.
--
-- `propWorld` is the marker rather than a token TYPE because the type list is
-- the more likely thing to gain a standard LSP name upstream; the world axis
-- is unambiguously this branch's invention.
--
-- MEASURED, because the older comment here claimed otherwise: as of the
-- patched build at d5f3797, the server does NOT gate its legend on the
-- `experimental.leanRichTokens` client capability. `leanRichTokens` appears
-- nowhere in its source, and speaking LSP to `lake serve` in
-- ~/LeanCourse/MathematicsInLean with and without the capability returns the
-- identical 29-type / 31-modifier rich legend both times. The capability is
-- still sent (see after/lsp/leanls.lua) so this client is already correct if a
-- gate ever lands, but nothing may be inferred FROM having sent it.
--
-- That is precisely why detection beats a flag, and why detection reads the
-- legend rather than the capability: the capability records what we asked for,
-- the legend records what we got, and right now those are independent.
--
-- ── the override ──────────────────────────────────────────────────────────
--   vim.g.lean_rich_tokens = nil    detect (default)
--   vim.g.lean_rich_tokens = false  force standard: withhold the capability
--                                   and run no rich client behaviour
--   vim.g.lean_rich_tokens = true   force rich, and complain if the legend
--                                   that came back does not actually carry the
--                                   names (which means the toolchain is stock,
--                                   not that the setting is wrong)
--
-- What forcing standard DOES: the capability is omitted from the wire, and
-- `M.enabled()` is false, so nothing keyed off this module runs.
--
-- What it does NOT do, on the current build: change the highlighting. The
-- server sends the rich token stream regardless, so the `@lsp.*.lean` groups
-- in lua/plugins/themes.lua keep matching. `:LeanRichTokens status` says so
-- out loud rather than letting the setting look more effective than it is.
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
--   MODE      is this client's, and is renegotiated by restarting the language
--             server — which `:LeanRichTokens on|off|toggle` does only when
--             the running client sent a DIFFERENT capability than the one now
--             wanted, since that is the only case where a restart can change
--             anything at all.
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
---@field warned boolean whether the setting and the legend disagree
---@field client_id integer|nil
---@field notified boolean whether THIS diagnosis raised the notification
M.last = {
  override = nil,
  legend_rich = nil,
  mode = "unknown",
  warned = false,
  notified = false,
  client_id = nil,
}

--- Has a server been observed sending the rich legend while this client
--- withheld the capability? nil until such a case is seen; false once it is.
---
--- That observation is what makes a restart pointless: if withholding does not
--- change the legend, restarting to withhold it again cannot either. Recorded
--- rather than assumed, because a future build may well add the gate.
---@type boolean|nil
M.server_gates = nil

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
--- True in BOTH the auto and the forced-on case — asking is the correct thing
--- for a client that wants the rich stream, whether or not it has decided to
--- use it yet. Only an explicit `false` withholds it.
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
  return vim.tbl_get(
    client,
    "server_capabilities",
    "semanticTokensProvider",
    "legend"
  )
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
---
--- `warned` is "the setting and the legend disagree", which is sticky for as
--- long as they do; `notified` is "this call raised the message", which fires
--- once per client. The two are separate so a caller can tell a persisting
--- mismatch from a fresh one.
---@param client vim.lsp.Client
---@return LeanRichTokensReport
function M.diagnose(client)
  local override = M.override()
  -- NOT `client and M.legend_is_rich(client) or nil`: that idiom collapses a
  -- legitimate `false` to nil, and false is the answer that matters here — it
  -- is the stock legend, i.e. the only case the warning below fires on. It
  -- silently disabled the whole forced-on warning until a stock-toolchain run
  -- showed `legend_rich=nil` where it should have said `false`.
  local rich = nil
  if client then
    rich = M.legend_is_rich(client)
  end
  local warned, notified = false, false

  if override == true and rich == false then
    warned = true
    if not warned_clients[client.id] then
      warned_clients[client.id] = true
      notified = true
      vim.notify(
        ("vim.g.lean_rich_tokens = true, but %s's legend has no `%s`.\n"):format(
          M.SERVER,
          M.MARKER
        )
          .. "This project is on a stock Lean toolchain; the rich token stream\n"
          .. "does not exist to be turned on. `:LeanRichTokens status` shows which\n"
          .. "toolchain elan resolved. Highlighting is unaffected — the rich groups\n"
          .. "simply match nothing.",
        vim.log.levels.WARN,
        { title = "LeanRichTokens" }
      )
    end
  end

  -- The measurement that makes a later restart pointless: we withheld the
  -- capability and the rich legend arrived anyway, so this server build does
  -- not gate on it. Only ever set from an observation, never assumed.
  if override == false and rich == true then
    M.server_gates = false
  end

  M.last = {
    override = override,
    legend_rich = rich,
    mode = (override == false or rich == false) and "standard"
      or (rich == true) and "rich"
      or "unknown",
    warned = warned,
    notified = notified,
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
  local out = vim
    .system({ "elan", "show" }, {
      cwd = cwd and vim.uv.fs_stat(cwd) and cwd or nil,
      env = { ELAN_NO_OVERRIDE_NOTICE = "1" },
      text = true,
    })
    :wait(5000)
  if out.code ~= 0 then
    return ("unknown (elan show exited %d)"):format(out.code)
  end
  -- The line after the `----` rule under "active toolchain", which carries the
  -- override reason in parentheses when there is one.
  local active = (out.stdout or ""):match(
    "active toolchain%s*\n%-+%s*\n%s*([^\n]+)"
  )
  return active and vim.trim(active)
    or "unknown (unrecognised `elan show` output)"
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
  -- Same `x and f() or nil` trap as in diagnose(): keep false as false.
  local rich = nil
  if client then
    rich = M.legend_is_rich(client)
  end
  local root = client and (client.root_dir or client.config.root_dir)
    or vim.uv.cwd()

  return {
    override = M.override(),
    -- What we WOULD send now …
    advertised = M.advertise(),
    -- … versus what the running client actually did send, read back off its own
    -- config. These differ exactly when vim.g changed without a restart, which
    -- is the state in which nothing the user asked for has taken effect yet.
    sent = client and vim.tbl_get(
      client.config,
      "capabilities",
      "experimental",
      "leanRichTokens"
    ) == true or false,
    client = client and { id = client.id, root_dir = root } or nil,
    legend_rich = rich,
    n_types = legend and legend.tokenTypes and #legend.tokenTypes or nil,
    n_mods = legend and legend.tokenModifiers and #legend.tokenModifiers
      or nil,
    marker = legend and legend.tokenModifiers and vim.tbl_contains(
      legend.tokenModifiers,
      M.MARKER
    ) or false,
    mode = M.enabled(bufnr) and "rich" or "standard",
    toolchain = M.toolchain(root),
    server_gates = M.server_gates,
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
    "  project root    : "
      .. tostring(r.client and r.client.root_dir or vim.uv.cwd()),
  }

  vim.list_extend(lines, {
    "",
    "  ── legend (the server decides, at initialize) ──",
  })
  if not r.client then
    vim.list_extend(lines, {
      "  no leanls client attached — nothing has been negotiated yet.",
      "  capability that WOULD be sent: "
        .. (
          r.advertised and "experimental.leanRichTokens = true"
          or "none (the key is omitted)"
        ),
    })
  else
    vim.list_extend(lines, {
      ("  client id       : %d"):format(r.client.id),
      -- "= false" would be a lie: the key is left out entirely, which is a
      -- different thing on the wire from sending it with a false value.
      "  capability sent : "
        .. (
          r.sent and "experimental.leanRichTokens = true"
          or "none (experimental.leanRichTokens omitted)"
        ),
      ("  legend size     : %d token types, %d modifiers"):format(
        r.n_types or 0,
        r.n_mods or 0
      ),
      ("  has `%s` : %s"):format(M.MARKER, yn(r.marker)),
    })

    -- Everything below is a DISAGREEMENT report. Each of these is a state a
    -- user can reach and be baffled by, and none of them is an error.

    -- The setting changed but the running server was never asked again.
    if r.sent ~= r.advertised then
      vim.list_extend(lines, {
        "",
        "  NOTE the running client sent leanRichTokens = "
          .. tostring(r.sent)
          .. "; the setting now",
        "       says "
          .. tostring(r.advertised)
          .. ". Nothing was renegotiated. `:LeanRichTokens "
          .. (r.advertised and "on" or "off")
          .. "` restarts",
        "       leanls when a restart could change the answer.",
      })
    end

    -- Forced off, and the rich stream is arriving anyway. Measured, not
    -- guessed: the patched build at d5f3797 does not gate its legend on the
    -- capability, so withholding it changes what this client ASKS FOR and
    -- nothing about what the server SENDS.
    if r.override == false and r.marker then
      vim.list_extend(lines, {
        "",
        "  NOTE standard mode is forced and the legend is still rich. This server",
        "       build does not gate its legend on the capability, so the rich",
        "       tokens keep arriving and the @lsp.*.lean groups keep matching.",
        "       What IS off: the capability is no longer advertised, and no rich",
        "       client behaviour runs. Highlighting is not this switch's to change.",
      })
    end

    -- elan says patched, the wire says stock.
    if r.toolchain:match("^lean4%-rich") and r.marker == false then
      vim.list_extend(lines, {
        "",
        "  NOTE elan resolved the patched toolchain but the legend is stock. The",
        "       running server is not the one elan now names — restart leanls.",
      })
    -- elan says stock, the wire says patched.
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
    "  Changing MODE      : :LeanRichTokens on|off|toggle — restarts leanls only",
    "                       when the running client sent a different capability",
    "                       than the one now wanted.",
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

  -- WHEN TO RESTART. Restarting leanls on a mathlib project costs a full
  -- re-elaboration, so the bar is "a restart could change something".
  --
  -- The test is the CAPABILITY the running client sent, not the legend it got.
  -- Comparing legends is the version of this that loops forever: forced-off
  -- against the patched build sees a rich legend, restarts, gets a rich legend
  -- again (the build does not gate), and would restart on every subsequent
  -- `off` — a minute of re-elaboration each time, achieving nothing. The
  -- capability comparison settles after one restart, because the new client
  -- sends what was asked for by construction.
  --
  -- And once M.server_gates is known false — observed, in diagnose() — even
  -- that one restart is pointless for the off direction, so it is skipped.
  local want = M.advertise()
  local clients = M.clients()
  local stale = false
  for _, client in ipairs(clients) do
    local sent = vim.tbl_get(
      client.config,
      "capabilities",
      "experimental",
      "leanRichTokens"
    ) == true
    if sent ~= want then
      stale = true
    end
  end

  local msg
  if #clients == 0 then
    msg = ("LeanRichTokens: %s — no %s running; takes effect when one starts."):format(
      mode,
      M.SERVER
    )
  elseif stale and M.server_gates == false then
    refresh_tokens()
    msg = ("LeanRichTokens: %s — client behaviour switched, tokens re-requested. "):format(
      mode
    ) .. "Not restarting: this server build was observed not to gate its legend on " .. "the capability, so renegotiating cannot change what arrives. " .. "`:LeanRichTokens status` has the detail."
  elseif stale and restart_server() then
    msg = ("LeanRichTokens: %s — restarted %s so the capability is renegotiated."):format(
      mode,
      M.SERVER
    )
  else
    refresh_tokens()
    msg = ("LeanRichTokens: %s — %s already sent that capability; re-requested tokens."):format(
      mode,
      M.SERVER
    )
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
