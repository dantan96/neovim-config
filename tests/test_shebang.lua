local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local shebang = require("config.shebang")

T["shebang"] = new_set()

T["shebang"]["shebangs table has expected filetypes"] = function()
  local expected = { "python", "sh", "bash", "zsh", "javascript", "lua" }
  for _, ft in ipairs(expected) do
    expect.equality(shebang.shebangs[ft] ~= nil, true)
  end
end

T["shebang"]["default shebang is set"] = function()
  expect.equality(type(shebang.default), "string")
  expect.equality(shebang.default:match("^#!") ~= nil, true)
end

T["shebang"]["all shebangs start with #!"] = function()
  for ft, sb in pairs(shebang.shebangs) do
    -- Pair the filetype into the assertion rather than dropping it: the
    -- table is iterated in arbitrary order, so a bare `true`/`false` failure
    -- would not say which entry was malformed.
    expect.equality({ ft, sb:match("^#!") ~= nil }, { ft, true })
  end
end

T["shebang"]["insert() defers chmod until buffer is written"] = function()
  local path = vim.fn.tempname() .. ".sh"
  MiniTest.finally(function()
    vim.fn.delete(path)
  end)

  vim.cmd("edit " .. vim.fn.fnameescape(path))
  vim.bo.filetype = "sh"
  shebang.insert()

  -- Shebang inserted in the buffer
  expect.equality(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], shebang.shebangs.sh)
  -- File not written yet: nothing on disk, so nothing to chmod
  expect.equality(vim.fn.filereadable(path), 0)

  vim.cmd("write")
  -- chmod runs async in the BufWritePost callback; give it a moment
  vim.wait(2000, function()
    return vim.fn.executable(path) == 1
  end, 50)
  expect.equality(vim.fn.executable(path), 1)
  vim.cmd("bwipeout!")
end

return T
