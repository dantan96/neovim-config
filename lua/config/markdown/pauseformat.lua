-- Format-on-pause for markdown: run the SAME conform chain that
-- format-on-save uses (prettier, lua/plugins/format.lua) whenever
-- typing pauses, so the buffer always sits at its saved shape.
-- Replaces the retired formatoptions-'a'/'t' live wrap
-- (config.markdown.hardwrap): prettier is markdown-aware, so unlike
-- Vim's internal formatter it never splits a `backtick span` and
-- never reflows fenced code blocks.
--
-- Two-flag gate, deliberately asymmetric:
--   vim.b.disable_autoformat  — formatting off (save AND pause);
--                               <leader>tf, plugins/format.lua
--   vim.b.disable_pauseformat — pause off, save unaffected;
--                               <leader>tw, this module
-- Pause runs only when BOTH are unset, so <leader>tf off always
-- silences pause too, and re-enabling it restores whatever
-- <leader>tw state the buffer had.
--
-- Efficiency: the debounce timer IS the pause heuristic — nothing
-- spawns until DEBOUNCE_MS pass without an edit. A changedtick guard
-- makes edit-free pauses cost nothing, and conform's async format
-- discards results if the buffer changed mid-run (the rare-race
-- safety net, not the engine). InsertLeave formats immediately: an
-- unambiguous pause.

local M = {}

M.DEBOUNCE_MS = 700

-- Per-buffer uv timers and last-formatted changedticks.
local timers = {}
local last_tick = {}

--- Would format-on-pause fire in this buffer (gates only, not the
--- changedtick guard)?
---@param buf integer|nil buffer id (default: current)
---@return boolean
function M.active(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return not (
    vim.g.disable_autoformat
    or vim.b[buf].disable_autoformat
    or vim.b[buf].disable_pauseformat
  )
    and vim.bo[buf].modifiable
    and not vim.bo[buf].readonly
    and vim.bo[buf].buftype == ""
end

local function fire(buf)
  if not (vim.api.nvim_buf_is_valid(buf) and M.active(buf)) then
    return
  end
  if last_tick[buf] == vim.api.nvim_buf_get_changedtick(buf) then
    return
  end
  require("conform").format({
    bufnr = buf,
    async = true,
    quiet = true,
    lsp_format = "fallback",
  }, function()
    if vim.api.nvim_buf_is_valid(buf) then
      last_tick[buf] = vim.api.nvim_buf_get_changedtick(buf)
    end
  end)
end

local function schedule(buf)
  local t = timers[buf]
  if not t then
    t = assert(vim.uv.new_timer())
    timers[buf] = t
  end
  t:stop()
  t:start(
    M.DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      fire(buf)
    end)
  )
end

local function cancel(buf)
  local t = timers[buf]
  if t then
    t:stop()
    t:close()
    timers[buf] = nil
  end
  last_tick[buf] = nil
end

function M.toggle()
  vim.b.disable_pauseformat = not vim.b.disable_pauseformat
  vim.notify("format-on-pause " .. (vim.b.disable_pauseformat and "off" or "on") .. " (buffer)")
end

-- Buffer-local wiring: must run for EVERY markdown buffer. Idempotent
-- (a :e reload re-runs ftplugins): the per-buffer augroup clears its
-- own previous autocmds, and vim.b flags survive the reload.
function M.attach()
  local buf = vim.api.nvim_get_current_buf()
  local group = vim.api.nvim_create_augroup("pauseformat_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = buf,
    callback = function()
      schedule(buf)
    end,
  })
  -- Leaving insert is an unambiguous pause: skip the debounce wait.
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = buf,
    callback = function()
      local t = timers[buf]
      if t then
        t:stop()
      end
      fire(buf)
    end,
  })
  -- Save just ran the sync format: mark the buffer clean so the
  -- TextChanged its edits produced doesn't spawn a no-op run.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = function()
      last_tick[buf] = vim.api.nvim_buf_get_changedtick(buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    buffer = buf,
    callback = function()
      cancel(buf)
    end,
  })

  vim.keymap.set("n", "<leader>tw", M.toggle, {
    buffer = true,
    desc = "Toggle format-on-pause (markdown)",
  })
end

-- Global command: registered once (under the ftplugin's once-guard).
function M.setup()
  vim.api.nvim_create_user_command("PauseFormatToggle", M.toggle, {
    desc = "Toggle format-on-pause (conform) for this buffer",
  })
end

return M
