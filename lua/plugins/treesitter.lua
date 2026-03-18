return {
  -- Core nvim-treesitter plugin configuration
  -- Provides syntax highlighting, indentation, and more using tree-sitter parsers
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate", -- Automatically update parsers on plugin updates
  event = { "BufReadPost", "BufNewFile" }, -- <— defer setup until a buffer exists

  -- Plugin dependencies
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },

  config = function()
    -- Basic treesitter setup
    require("nvim-treesitter.configs").setup({
      sync_install = true,
      ignore_install = {},
      modules = {},
      -- stylua: ignore
      ensure_installed = {
        "agda", "awk", "bash", "c", "cmake", "cpp",
        "css", "dockerfile", "fish", "fsharp",
        "go", "haskell", "html", "javascript", "json",
        "lua", "luadoc", "make", "markdown", "markdown_inline",
        "ocaml", "python", "query", "regex", "ruby", "rust",
        "toml", "tsx", "typescript", "vim", "vimdoc", "yaml"
      },
      -- stylua: resume
      auto_install = false, -- Disable installation notifications
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        -- = { "fsharp", },
      },
      indent = {
        enable = true,
        -- disable = { "fsharp" },
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

    ---@class MyParserConfigs: table<string, any>
    local parser_config =
      require("nvim-treesitter.parsers").get_parser_configs()
    parser_config.spthy = {
      install_info = {
        url = vim.fn.expand("~") .. "/tamarin-prover/tree-sitter/tree-sitter-spthy",
        files = { "src/parser.c", "src/scanner.c" },
        branch = "develop",
        requires_generate_from_grammar = false,
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
