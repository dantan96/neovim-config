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
    },
    opts = {
      format_on_save = function(bufnr)
        -- Escape hatch: for markdown, save-time prettier IS the
        -- hard-wrap engine (see formatters.prettier below), so this is
        -- the only way to save without reflow.
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
        -- formatter — live typing-wrap is therefore off by default
        -- (config.markdown.hardwrap). remark still serves the lint /
        -- LSP ecosystem (config.remark_auto, remark_ls); it just no
        -- longer formats on save.
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
        prettier = {
          prepend_args = { "--prose-wrap", "always", "--print-width", "65" },
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
