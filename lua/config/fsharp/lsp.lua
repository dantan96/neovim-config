-- lua/config/fsharp/lsp.lua
-- fsautocomplete boot. Raw vim.lsp.start (not lsp/*.lua + vim.lsp.enable)
-- because the root/semantic-token logic below is per-buffer: see the
-- loose-file handling. Called from after/ftplugin/fsharp.lua for every
-- F# buffer; vim.lsp.start dedups per (name, root_dir).

local M = {}

--- Start (or reuse) fsautocomplete for `bufnr`.
function M.start(bufnr)
  -- Don't start a second client if one is already active for this buffer
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == "fsautocomplete" then
      return
    end
  end

  local fname = vim.api.nvim_buf_get_name(bufnr)
  local util = require("lspconfig.util")
  local root = util.root_pattern("*.sln", "*.fsproj", ".git")(fname)
    or vim.fs.dirname(fname)

  -- A .fs file with no *.fsproj/*.sln ancestor can never belong to a
  -- loaded FSAC project, so every semantic-tokens request for it fails
  -- with -32603 ("Couldn't find <file> in LoadedProjects"). Neovim 0.12
  -- issues semanticTokens/range requests whenever the visible range
  -- changes, so those failures fire on every scroll. Dropping the
  -- provider in on_attach (before the deferred capability init) means
  -- no request is ever sent for such buffers.
  local proj_root = util.root_pattern("*.sln", "*.fsproj")(fname)

  -- Raw vim.lsp.start() bypasses vim.lsp.config("*"), so the blink.cmp
  -- capabilities applied to every other server must be passed here.
  local caps_ok, blink = pcall(require, "blink.cmp")

  vim.lsp.start({
    name = "fsautocomplete",
    cmd = { "fsautocomplete" },
    filetypes = { "fsharp", "fs", "fsx", "fsi" },
    root_dir = root,
    capabilities = caps_ok and blink.get_lsp_capabilities() or nil,
    on_attach = function(client)
      if not proj_root then
        client.server_capabilities.semanticTokensProvider = nil
      end
    end,
    init_options = { AutomaticWorkspaceInit = true },
    settings = {
      FSharp = {
        -- hard disable the parentheses nag
        UnnecessaryParenthesesAnalyzer = false,

        -- (optional) if you also dislike other "style nags":
        -- SimplifyNameAnalyzer = false,
        -- UnusedOpensAnalyzer = true,
        -- UnusedDeclarationsAnalyzer = true,
        -- Linter = true, -- FSharpLint integration
      },
    },
  })
end

return M
