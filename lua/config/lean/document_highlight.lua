-- lua/config/lean/document_highlight.lua — occurrence highlighting for Lean.
--
-- WHAT AND WHY
--
-- Rest the cursor on an identifier and every occurrence of THAT BINDING lights
-- up. VS Code does this automatically (vscode-lean4 manual.md:456-460); the
-- Lean server has advertised documentHighlightProvider all along
-- (Watchdog.lean:1579) and nothing in Neovim calls it on its own.
--
-- `*` is not a substitute, and this is the one place where "generic already
-- covers it" is plainly false. Lean shadows aggressively — `obtain ⟨x, hx⟩ := h`
-- introduces an `x` that is a different binding from the enclosing `x` — and
-- `*` is a text search, so it highlights both. The upstream manual makes
-- exactly this point in a screenshot caption (manual.md:466). The server knows
-- which occurrences are the same binding; a regex cannot.
--
-- WHY THIS FILE, AND NOT after/ftplugin/lean.lua
--
-- The feature is autocmds, and tests/test_invariants.lua asserts that
-- re-sourcing an ftplugin leaves the autocmd population unchanged — an
-- ftplugin re-runs on every :edit, so autocmds defined there accumulate. A
-- module required once from the lean.nvim spec's `init` runs exactly once, at
-- startup, which is also early enough for the LspAttach hook below to see the
-- first Lean file of the session.
--
-- WHY LspAttach AND NOT FileType
--
-- The buffer-scoped autocmds are only worth having once a client that can
-- answer the request is attached, and `client:supports_method` is the honest
-- test for that. It also means nothing is registered in a Lean file opened
-- outside a Lake project, where no server ever starts.

local M = {}

local GROUP = "LeanDocumentHighlight"

---Is the current buffer a Lean SOURCE buffer with the cursor in normal mode?
---
---The infoview is the reason this is not just a filetype check on paper: its
---buffers are `leaninfo`, they are Neovim buffers like any other, and lean.nvim
---puts a real cursor in them (`\<Tab>` jumps there, `]g`/`[h` move around
---inside). Highlighting occurrences of a hypothesis name inside a rendered goal
---state would be noise over a read-only pretty-printed pane. Excluded by
---filetype, as well as structurally by the autocmds being buffer-scoped to
---Lean buffers.
local function should_highlight()
  return vim.bo.filetype == "lean" and vim.fn.mode() == "n"
end

---@param buf integer
local function attach(buf)
  -- Idempotent: LspAttach fires again after :LspRestart, and duplicating the
  -- pair would fire the request twice per hold. Buffer-scoped clears leave the
  -- global LspAttach hook below untouched.
  vim.api.nvim_clear_autocmds({ group = GROUP, buffer = buf })

  vim.api.nvim_create_autocmd("CursorHold", {
    group = GROUP,
    buffer = buf,
    desc = "Lean: highlight occurrences of the symbol under the cursor",
    callback = function()
      if should_highlight() then
        vim.lsp.buf.document_highlight()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "WinLeave" }, {
    group = GROUP,
    buffer = buf,
    desc = "Lean: clear occurrence highlights",
    callback = function()
      -- WinLeave covers `\<Tab>` into the infoview: CursorMoved fires in the
      -- infoview buffer, not this one, so without it the stale highlights
      -- would sit in the source window for as long as you stayed away.
      vim.lsp.buf.clear_references()
    end,
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })

  -- 'updatetime' is what CursorHold waits for, and it is global-only — there
  -- is no buffer scope to hide in. At Neovim's default 4000 ms the feature
  -- would technically work and never once be seen. 500 ms is the usual
  -- compromise; the guard means an explicit lower value set anywhere else
  -- wins, so this only ever raises responsiveness.
  if vim.o.updatetime > 500 then
    vim.o.updatetime = 500
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    desc = "Lean: enable occurrence highlighting when leanls attaches",
    callback = function(args)
      local buf = args.buf
      if vim.bo[buf].filetype ~= "lean" then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or not client:supports_method("textDocument/documentHighlight", buf) then
        return
      end
      attach(buf)
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    desc = "Lean: stop occurrence highlighting when the server goes away",
    callback = function(args)
      vim.api.nvim_clear_autocmds({ group = GROUP, buffer = args.buf })
      pcall(vim.lsp.buf.clear_references)
    end,
  })
end

return M
