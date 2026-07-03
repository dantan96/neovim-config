local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values

local M = {}

local live_multigrep = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job({
    command_generator = function(prompt)
      if not prompt or prompt == "" then
        return nil
      end

      -- Prompt format: <pattern>[  <glob>[  <glob>...]] (two-space separated).
      -- The first segment is the rg pattern; every following segment is
      -- passed as a -g file glob (previously segments past the second were
      -- silently ignored).
      local pieces = vim.split(prompt, "  ")
      local args = { "rg" }
      if pieces[1] then
        table.insert(args, "-e")
        table.insert(args, pieces[1])
      end

      for i = 2, #pieces do
        table.insert(args, "-g")
        table.insert(args, pieces[i])
      end

      return vim.iter({
        args,
        {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
        },
      }):flatten():totable()
    end,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd,
  })

  pickers
    .new(opts, {
      debounce = 100,
      prompt_title = "Multi Grep",
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = require("telescope.sorters").empty(),
    })
    :find()
end

M.setup = function()
  vim.keymap.set("n", "<leader>fg", live_multigrep, {
    desc = "Multigrep (pattern  glob...)",
  })
  vim.keymap.set("n", "<leader>fG", function()
    live_multigrep({ cwd = vim.fn.expand("~/.config/nvim") })
  end, { desc = "Multigrep in nvim config" })
end

return M
