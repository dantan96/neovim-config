return {
  -- Core nvim-treesitter plugin configuration
  -- Provides syntax highlighting, indentation, and more using tree-sitter parsers
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate", -- Automatically update parsers on plugin updates
  priority = 1000, -- Load treesitter early in the startup process
  lazy = false, -- Disable lazy loading to ensure immediate availability

  -- Plugin dependencies
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },

  config = function()
    -- Basic treesitter setup
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "query",

        -- Shell/Terminal
        "bash",
        "fish",
        "make",
        "awk",
        "cmake",
        "dockerfile",

        -- Web Development
        "css",
        "html",
        "javascript",
        "json",
        "tsx",
        "typescript",
        "yaml",

        -- Systems Programming
        "c",
        "cpp",
        "rust",
        "go",

        -- Functional Programming
        "haskell",
        "ocaml",
        "fsharp",

        -- Scripting
        "lua",
        "luadoc",
        "python",
        "ruby",

        -- Documentation/Config
        "markdown",
        "markdown_inline",
        "regex",
        "toml",
        "vim",
        "vimdoc",
      },
      auto_install = false, -- Disable installation notifications
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = {
          "fsharp",
        },
      },
      indent = {
        enable = true,
        disable = {
          "fsharp",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- automatically jump forward to text-object
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = { ["]m"] = "@function.outer" },
          goto_previous_start = { ["[m"] = "@function.outer" },
        },
      },
    })

    -- -- Add parser path to runtimepath
    -- local parser_path = vim.fn.stdpath("config") .. "/parser"
    -- vim.opt.runtimepath:append(parser_path)
    --
    -- -- Register the spthy parser if it exists
    -- local spthy_parser_path = parser_path .. "/spthy.so"
    -- if vim.fn.filereadable(spthy_parser_path) == 1 then
    --   -- Direct language registration
    --   pcall(function()
    --     vim.treesitter.language.register('spthy', 'spthy')
    --   end)
    --
    --   -- Also add the parser for spthy
    --   pcall(function()
    --     vim.treesitter.language.add('spthy', {
    --       path = spthy_parser_path
    --     })
    --   end)
    --
    --   -- Ensure the parser can be loaded
    --   pcall(function()
    --     vim.treesitter.language.require_language("spthy")
    --   end)
    -- end
    local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
    parser_config.spthy = {
      install_info = {
        url = "/home/daniel.tanios/tamarin-prover/tree-sitter/tree-sitter-spthy",
        files = { "src/parser.c", "src/scanner.c" },
        -- optional entries:
        branch = "develop", -- default branch in case of git repo if different from master
        requires_generate_from_grammar = false, -- if folder contains pre-generated src/parser.c
      },
    }
    parser_config.fsharp = {
      install_info = {
        url = "https://github.com/ionide/tree-sitter-fsharp",
        branch = "main",
        files = { "src/scanner.c", "src/parser.c" },
        location = "fsharp",
      },
      requires_generate_from_grammar = false,
      filetype = "fsharp",
    }
  end,
}
