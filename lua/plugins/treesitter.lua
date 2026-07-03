-- nvim-treesitter on the `main` rewrite (the old `master` branch is frozen).
-- main no longer has configs.setup()/modules: parsers are installed with
-- require("nvim-treesitter").install(), and highlighting/indent are enabled
-- per-buffer from a FileType autocmd via vim.treesitter.start().
--
-- Custom grammars:
--  * fsharp: ionide/tree-sitter-fsharp IS the upstream grammar on main, so
--    the old install_info override is no longer needed.
--  * spthy: loads natively from parser/spthy.so + queries/spthy in this
--    config (no nvim-treesitter involvement). Grammar source lives at
--    ~/tamarin-prover/tree-sitter/tree-sitter-spthy for regenerating.

-- stylua: ignore
local ensure_installed = {
  "agda", "awk", "bash", "c", "cmake", "cpp",
  "css", "dockerfile", "fish", "fsharp",
  "go", "haskell", "html", "javascript", "json",
  "lua", "luadoc", "make", "markdown", "markdown_inline",
  "ocaml", "python", "query", "regex", "ruby", "rust",
  "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup({})

      -- Async; only invoked for parsers actually missing so a normal
      -- startup does no install work at all.
      local installed = {}
      for _, lang in ipairs(ts.get_installed()) do
        installed[lang] = true
      end
      local missing = vim.tbl_filter(function(lang)
        return not installed[lang]
      end, ensure_installed)
      if #missing > 0 then
        ts.install(missing)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if not vim.treesitter.language.add(lang) then
            return -- no parser for this filetype
          end
          vim.treesitter.start(args.buf, lang)
          vim.bo[args.buf].indentexpr =
            "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      -- The plugin loads on BufReadPost, i.e. after the first buffer's
      -- FileType already fired — cover that buffer explicitly.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
          vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
        end
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local function sel(query)
        return function() select.select_textobject(query, "textobjects") end
      end
      vim.keymap.set({ "x", "o" }, "af", sel("@function.outer"), { desc = "Function (outer)" })
      vim.keymap.set({ "x", "o" }, "if", sel("@function.inner"), { desc = "Function (inner)" })
      vim.keymap.set({ "x", "o" }, "ac", sel("@class.outer"), { desc = "Class (outer)" })
      vim.keymap.set({ "x", "o" }, "ic", sel("@class.inner"), { desc = "Class (inner)" })
      vim.keymap.set({ "n", "x", "o" }, "]m", function()
        move.goto_next_start("@function.outer", "textobjects")
      end, { desc = "Next function start" })
      vim.keymap.set({ "n", "x", "o" }, "[m", function()
        move.goto_previous_start("@function.outer", "textobjects")
      end, { desc = "Prev function start" })
    end,
  },
}
