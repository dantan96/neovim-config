---@meta

-- =========================
-- vim core
-- =========================

---@class vim
vim = vim

-- =========================
-- vim.opt (the big one)
-- =========================

---@class vim.Option
local Option = {}

---@return any
function Option:get() end

---@param value any
function Option:append(value) end

---@param value any
function Option:remove(value) end

---@param value any
function Option:prepend(value) end

---@type table<string, any>
vim.opt = {}

-- =========================
-- vim.o / vim.bo / vim.wo
-- =========================

---@type table<string, any>
vim.o = {}

---@type table<string, any>
vim.bo = {}

---@type table<string, any>
vim.wo = {}

-- =========================
-- vim.fs (LuaLS hates this)
-- =========================

---@class vim.fs
vim.fs = vim.fs or {}

---@param names string|string[]
---@param opts table
---@return string[]
function vim.fs.find(names, opts) end

---@param path string
---@return string
function vim.fs.dirname(path) end

-- =========================
-- vim.uv (aka libuv wrapper)
-- =========================

---@class vim.uv
vim.uv = vim.uv or {}

---@param path string
---@return table|nil
function vim.uv.fs_stat(path) end

-- =========================
-- vim.api (minimal patching)
-- =========================

---@class vim.api
vim.api = vim.api or {}

---@param name string
---@return string
function vim.api.nvim_buf_get_name(name) end

---@return string[]
function vim.api.nvim_get_runtime_file(_, _) end

-- =========================
-- vim.lsp (common offenders)
-- =========================

---@class vim.lsp.Client
---@field name string
---@field server_capabilities table

---@class vim.lsp
vim.lsp = vim.lsp or {}

---@param id number
---@return vim.lsp.Client|nil
function vim.lsp.get_client_by_id(id) end

---@param name string
---@param config table
function vim.lsp.config(name, config) end

---@param name string
function vim.lsp.enable(name) end

-- =========================
-- vim.fn (loose, pragmatic)
-- =========================

---@class vim.fn
vim.fn = vim.fn or {}

---@param name string
---@return any
function vim.fn.expand(name) end

---@param name string
---@return string
function vim.fn.stdpath(name) end
