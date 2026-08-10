-- lua/plugins/format.lua
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        -- <leader>F (not <leader>f): telescope's <leader>f* family would
        -- stall a single-char <leader>f for timeoutlen on every press.
        "<leader>F",
        function()
          require("conform").format({
            lsp_format = "fallback",
            async = false,
            timeout_ms = 4000, -- a bit more generous than 2000
          })
        end,
        mode = { "n", "v" },
        desc = "Format buffer (Conform)",
      },
      {
        -- Master formatting switch: gates save (format_on_save below)
        -- AND pause (config.markdown.pauseformat). <leader>tw narrows
        -- to pause-only.
        "<leader>tf",
        function()
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          vim.notify("formatting " .. (vim.b.disable_autoformat and "off" or "on") .. " (save+pause, buffer)")
        end,
        desc = "Toggle formatting (save+pause, buffer)",
      },
    },
    opts = {
      format_on_save = function(bufnr)
        -- Escape hatch (<leader>tf; auto-set by config.prettier_ignore
        -- for .prettierignore'd files): for markdown, prettier IS the
        -- hard-wrap engine (see formatters.prettier below), so this is
        -- the way to save without reflow.
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return nil
        end
        return {
          timeout_ms = 2000,
          lsp_format = "fallback", -- use LSP formatting when no formatter matches
          quiet = true, -- suppress "Formatters unavailable" when no formatter matches
        }
      end,
      formatters_by_ft = {
        toml = { "taplo" },
        lua = { "stylua" },
        python = { "ruff_fix", "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        -- zsh is intentionally omitted: shfmt has no zsh dialect and can
        -- corrupt zsh scripts.
        -- fantomas lives in ~/.dotnet/tools (on the login-shell PATH).
        fsharp = { "fantomas" },

        -- prettier, not remark: prettier's --prose-wrap does the
        -- markdown hard-wrapping (width = 'textwidth') and never
        -- breaks inside a `backtick span`, unlike Vim's internal
        -- formatter — Vim's own typing-wrap stays off, and live
        -- formatting is conform-on-pause instead
        -- (config.markdown.pauseformat), same chain as save. remark
        -- still serves the lint / LSP ecosystem (config.remark_auto,
        -- remark_ls); it just no longer formats on save.
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
      },
      formatters = {
        -- taplo and prettier use conform's builtin definitions. Do not add
        -- --plugin=prettier-plugin-toml to prettier: mason's prettier shadows
        -- PATH inside nvim and lacks that plugin, so resolution would fail
        -- for every filetype prettier runs on.
        -- CLI flags override project .prettierrc files, so markdown
        -- wraps at 65 everywhere nvim formats it — deliberate, to
        -- match the global markdown textwidth/colorcolumn. prettier
        -- only appears in the markdown/mdx chains above, so these
        -- args reach no other filetype.
        --
        -- --tab-width 4 is the same deal for indent, matching the
        -- global shiftwidth (init.lua). Without it prettier indents a
        -- nested list item to its parent's *content offset*, which is
        -- marker-dependent — 2 for "- ", 3 for "1. ", 4 for "10. " —
        -- so >> and <Tab> disagreed with every format run and no
        -- single shiftwidth could fix it (2 matches "- " but flattens
        -- ordered lists, which need 3). --tab-width collapses that
        -- variance to a constant 4 for every marker, so vim and
        -- prettier agree exactly. Fenced blocks and continuation
        -- paragraphs shift with their list item; content inside a
        -- fence is untouched.
        prettier = {
          prepend_args = { "--prose-wrap", "always", "--print-width", "65", "--tab-width", "4" },
          -- Prettier resolves .prettierignore relative to CWD only (no
          -- upward walk), so run from the ignore file's root when one
          -- exists: ignored files then pass through unchanged. Config
          -- resolution is unaffected (.prettierrc is found by walking
          -- up from --stdin-filepath, and the args above override it
          -- anyway). config.prettier_ignore probes the same root.
          -- Deferred require: a bare one here would force-load conform
          -- at spec-parse time, defeating the BufWritePre lazy-load.
          cwd = function(self, ctx)
            return require("conform.util").root_file({ ".prettierignore" })(self, ctx)
          end,
        },
        ruff_fix = {
          prepend_args = { "--fix-only", "--unsafe-fixes" },
        },
        ruff_format = {
          -- line-length comes from pyproject.toml; no overrides needed
        },
        stylua = {

          prepend_args = { "--column-width", "79" },
        },
        shfmt = {
          prepend_args = { "-i", "2", "-ci" }, -- 2-space indent, indent switch cases
        },
      },
    },
  },
}
