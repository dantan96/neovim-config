---@type vim.lsp.Config
return {
  filetypes = { "markdown", "markdown.mdx" },
  settings = { remark = { requireConfig = false } },
  root_dir = function(bufnr, on_dir)
    local roots = require("config.roots")
    local fname = vim.api.nvim_buf_get_name(bufnr)
    on_dir(roots.find(fname, roots.all_markers))
  end,
}
