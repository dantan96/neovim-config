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
      format_on_save = {
        timeout_ms = 2000,
        lsp_format = "fallback", -- use LSP formatting when no formatter matches
        quiet = true, -- suppress "Formatters unavailable" when no formatter matches
      },
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

        markdown = { "remark", "prettier", stop_after_first = true },
        ["markdown.mdx"] = { "remark", "prettier", stop_after_first = true },
      },
      formatters = {
        -- taplo and prettier use conform's builtin definitions. Do not add
        -- --plugin=prettier-plugin-toml to prettier: mason's prettier shadows
        -- PATH inside nvim and lacks that plugin, so resolution would fail
        -- for every filetype prettier runs on.
        -- remark-cli loads .remarkrc.json which references remark-gfm etc.
        -- Those packages must be resolvable — either from the project's own
        -- node_modules or from the shared ~/.config/.remarks/node_modules
        -- (maintained by config/remark_auto.lua). Without them Node exits
        -- with a module-not-found error and conform shows a crash. This
        -- condition skips the formatter silently when they're absent.
        remark = {
          command = "remark",
          -- No --frail: it makes remark exit non-zero on any lint warning,
          -- which conform treats as failure and discards the output.
          args = { "--no-color", "--quiet" },
          stdin = true,
          condition = function(_, ctx)
            local shared =
              vim.fn.expand("~/.config/.remarks/node_modules/remark-gfm")
            if vim.fn.isdirectory(shared) == 1 then
              return true
            end
            local found = vim.fs.find("node_modules", {
              path = ctx.dirname,
              upward = true,
              type = "directory",
              limit = 1,
            })
            if #found == 0 then
              return false
            end
            return vim.fn.isdirectory(found[1] .. "/remark-gfm") == 1
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
