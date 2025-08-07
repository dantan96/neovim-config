vim.opt_local.shiftwidth = 2
vim.opt.relativenumber = true
vim.opt.number = true

-- after/ftplugin/lua.lua
-- Override the @property capture for Lua only:
vim.api.nvim_set_hl(0, "@property", { fg = "#eba0ac" })
-- vim.api.nvim_set_hl(0, "@lsp", { fg = "" })
vim.api.nvim_set_hl(0, "@lsp.typemod.variable.defaultLibrary.lua", { fg = "#fab387" })
vim.api.nvim_set_hl(0, "@lsp.typemod.function.defaultLibrary.lua", { fg = "#fab387", italic = true })
vim.api.nvim_set_hl(0, "@lsp.typemod.parameter.declaration.lua", { fg = "#f38ba8", underline = true, bold = true })
vim.api.nvim_set_hl(0, "@lsp.type.parameter.lua", { fg = "#f38ba8", underline = true, bold = true })
vim.api.nvim_set_hl(0, "@lsp.typemod.variable.declaration.lua", { fg = "#cdd6f4" })
vim.api.nvim_set_hl(0, "@lsp.typemod.function.declaration.lua", { fg = "#89b4fa" })
vim.api.nvim_set_hl(0, "@lsp.typemod.variable.global.lua", { fg = "#ff69b4" })

-- neon pink = "#fe019a"
-- hotpink = "#ff69b4"
-- rosewater = "#f5e0dc",
-- 	flamingo = "#f2cdcd",
-- 	pink = "#f5c2e7",
-- 	mauve = "#cba6f7",
-- 	red = "#f38ba8",
-- 	maroon = "#eba0ac",
-- 	peach = "#fab387",
-- 	yellow = "#f9e2af",
-- 	green = "#a6e3a1",
-- 	teal = "#94e2d5",
-- sky = "#89dceb",
-- sapphire = "#74c7ec",
-- blue = "#89b4fa",
-- lavender = "#b4befe",
-- text = "#cdd6f4",
-- subtext1 = "#bac2de",
-- subtext0 = "#a6adc8",
-- overlay2 = "#9399b2",
-- overlay1 = "#7f849c",
-- overlay0 = "#6c7086",
