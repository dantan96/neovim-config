-- Colorschemes for derived Ghostty profiles (GhosttyNu, GhosttyXonsh, ...).
-- Inert in plain Ghostty: when config.ghostty_profile detects no theme this
-- module contributes nothing at all (catppuccin owns that world; see the
-- `enabled` gate in themes.lua and the baseline in tests/test_profile_theme.lua).
local theme = require("config.ghostty_profile").theme()
if theme == nil then
  return {}
end

-- One recipe per GHOSTTY_NVIM_THEME value (injected by the Ghostty variant
-- configs under ~/.config/ghostty/variants/). Custom syntax-color hooks
-- stand down in derived profiles; the recipe scheme's capture defaults do
-- the coloring (accepted trade: consistency over customization).
--
-- Recipe shape:
--   plugin/name  lazy.nvim spec source (must NOT be a plugin that already
--                has its own configured spec — lazy merges specs and our
--                config would clobber the real one; that bug already
--                happened with mini.nvim)
--   colorscheme  applied via :colorscheme, OR
--   apply        function that paints directly (setup-style schemes)
--   background   'light'|'dark', pre-set to keep OSC-11 autodetect a no-op
--   decorate     optional highlight touch-ups, reapplied on every
--                ColorScheme so they survive reloads
-- Merge new attributes onto a group's existing definition (nvim_set_hl
-- REPLACES wholesale; this preserves e.g. a theme's segment fg colors).
local function restyle(group, opts)
  -- config.hl re-keys the read shape into the write shape; see that file for
  -- why the two differ and why passing the read straight back can throw.
  local hl = require("config.hl").snapshot(group, { link = false })
  for k, v in pairs(opts) do
    hl[k] = v
  end
  vim.api.nvim_set_hl(0, group, hl)
end

-- Statusline model (lualine A/B/C gradient): A = mode chip (accent bg),
-- B = devinfo/fileinfo/location (one tone raised), C = filename (on the
-- bar). Two material treatments: paper profiles ANCHOR (continuous bar,
-- furniture on the page); glass profiles FLOAT (pill segments, gaps stay
-- transparent — islands of light).
local function anchor_statusline(bar, raised, inactive_fg)
  restyle("StatusLine", { bg = bar })
  restyle("StatusLineNC", { bg = bar })
  restyle("MiniStatuslineFilename", { bg = bar })
  restyle("MiniStatuslineDevinfo", { bg = raised })
  restyle("MiniStatuslineFileinfo", { bg = raised })
  vim.api.nvim_set_hl(0, "MiniStatuslineLocation", { bg = raised, fg = inactive_fg })
  restyle("MiniStatuslineInactive", { bg = bar, fg = inactive_fg })
end

-- nu-glass statusline pill palettes live in statusline_palettes.toml (one
-- entry per beloved-theme lift, citations there). Tiny TOML-subset reader:
-- [section] headers and key = "string" pairs; anything else is ignored. A
-- real parser dependency isn't worth it for this shape.
local function read_pill_palettes()
  local path = vim.fn.stdpath("config") .. "/statusline_palettes.toml"
  local f = io.open(path, "r")
  if f == nil then
    return nil
  end
  local palettes, order, section, default = {}, {}, nil, nil
  for line in f:lines() do
    local name = line:match("^%s*%[([%w%-_]+)%]%s*$")
    if name ~= nil then
      section = {}
      palettes[name] = section
      order[#order + 1] = name
    else
      local k, v = line:match('^%s*([%w_]+)%s*=%s*"([^"]*)"')
      if k ~= nil then
        if section ~= nil then
          section[k] = v
        elseif k == "default" then
          default = v
        end
      end
    end
  end
  f:close()
  if #order == 0 then
    return nil
  end
  return { palettes = palettes, order = order, default = default }
end

-- Fallback = tokyonight-storm's lualine b/c (the committed baseline), so a
-- missing/garbled toml degrades to a known-good bar, and partial entries
-- inherit storm values per key.
local PILL_FALLBACK = {
  devinfo_fg = "#7aa2f7",
  devinfo_bg = "#3b4261",
  filename_fg = "#a9b1d6",
  filename_bg = "#1f2335",
  fileinfo_fg = "#a9b1d6",
  fileinfo_bg = "#1f2335",
  inactive_fg = "#737aa2",
  inactive_bg = "#1f2335",
}

local function current_pills()
  local cfg = read_pill_palettes()
  if cfg == nil then
    return PILL_FALLBACK
  end
  local name = vim.g.nu_glass_pill_palette or cfg.default or cfg.order[1]
  local entry = cfg.palettes[name] or cfg.palettes[cfg.order[1]]
  return vim.tbl_extend("force", PILL_FALLBACK, entry or {})
end

local RECIPES = {
  vellum = {
    plugin = "kepano/flexoki-neovim",
    name = "flexoki",
    colorscheme = "flexoki-light",
    background = "light",
    decorate = function()
      -- Flexoki Light's faintest grays vanish over translucent paper;
      -- conservatively darken ONLY legibility-critical groups. The comment
      -- darkening is toggleable (<leader>tc): sometimes melting-into-the-
      -- paper is the wanted mood.
      if vim.g.vellum_comment_soft_fg == nil then
        -- Remember flexoki's own faint ink before darkening: the toggle's
        -- "soft" state restores the theme's true value, not a guess.
        local orig = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
        vim.g.vellum_comment_soft_fg = orig.fg
          and string.format("#%06x", orig.fg)
          or "#b7b5ac"
      end
      if vim.g.vellum_comments_soft ~= true then
        vim.api.nvim_set_hl(0, "Comment", { fg = "#6f6e69", italic = true })
      end
      vim.api.nvim_set_hl(0, "LineNr", { fg = "#878580" })
      -- Anchored bar: Flexoki base-50 sill, base-100 raised segments.
      anchor_statusline("#f2f0e5", "#e6e4d9", "#6f6e69")
    end,
    keymaps = function()
      vim.keymap.set("n", "<leader>tc", function()
        vim.g.vellum_comments_soft = not vim.g.vellum_comments_soft
        if vim.g.vellum_comments_soft then
          -- The theme's own faint ink: melts into the paper.
          vim.api.nvim_set_hl(0, "Comment", {
            fg = vim.g.vellum_comment_soft_fg or "#b7b5ac",
            italic = true,
          })
        else
          vim.api.nvim_set_hl(0, "Comment", { fg = "#6f6e69", italic = true })
        end
      end, { desc = "Toggle comment softness (vellum)" })
    end,
  },
  ["flexoki-dark"] = {
    plugin = "kepano/flexoki-neovim",
    name = "flexoki",
    colorscheme = "flexoki-dark",
    background = "dark",
    decorate = function()
      -- Same anchor, night materials: base-850 sill, base-800 raised.
      anchor_statusline("#1c1b1a", "#282726", "#878580")
    end,
  },
  ["nu-glass"] = {
    -- Ghostty's stock palette IS Tomorrow Night, so use the maintained,
    -- hand-curated port (RRethy/base16-nvim: real per-group design,
    -- treesitter + LSP) with its canonical palette — except base00, which
    -- stays the glass ground. Never recolor the background: that belongs
    -- to the terminal.
    plugin = "RRethy/base16-nvim",
    name = "base16-colorscheme",
    background = "dark",
    apply = function()
      require("base16-colorscheme").setup({
        base00 = "#0d0e1a", -- glass ground (cleared to NONE anyway)
        base01 = "#282a2e",
        base02 = "#373b41",
        base03 = "#969896",
        base04 = "#b4b7b4",
        base05 = "#c5c8c6",
        base06 = "#e0e0e0",
        base07 = "#ffffff",
        base08 = "#cc6666",
        base09 = "#de935f",
        base0A = "#f0c674",
        base0B = "#b5bd68",
        base0C = "#8abeb7",
        base0D = "#81a2be",
        base0E = "#b294bb",
        base0F = "#a3685a",
      })
      vim.g.colors_name = "nu-glass-tomorrow"
    end,
    decorate = function()
      -- Chrome only, never syntax. Mode chips stay consonant (Tomorrow's
      -- own accents — hot neon proved jarring); starship's palette spices
      -- the quieter chrome instead: slate line numbers with a cyan cursor
      -- line, slate tildes and separators, violet git segment.
      local chips = {
        MiniStatuslineModeNormal = "#81a2be",
        MiniStatuslineModeInsert = "#b5bd68",
        MiniStatuslineModeVisual = "#b294bb",
        MiniStatuslineModeReplace = "#cc6666",
        MiniStatuslineModeCommand = "#f0c674",
        MiniStatuslineModeOther = "#8abeb7",
      }
      for group, bg in pairs(chips) do
        vim.api.nvim_set_hl(0, group, { fg = "#0d0e1a", bg = bg, bold = true })
        -- Column box: full mode treatment (same bg and fg as the mode and
        -- line boxes) — nu opts in; other profiles keep the neutral default.
        vim.api.nvim_set_hl(0, group .. "Col", { link = group })
      end
      -- Floating pills: whichever statusline_palettes.toml entry is active
      -- (each a beloved theme's lualine/airline b/c sections, citations in
      -- the toml; <leader>tp cycles). Gaps transparent.
      local p = current_pills()
      vim.api.nvim_set_hl(0, "MiniStatuslineDevinfo", { fg = p.devinfo_fg, bg = p.devinfo_bg })
      vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = p.filename_fg, bg = p.filename_bg })
      vim.api.nvim_set_hl(0, "MiniStatuslineFileinfo", { fg = p.fileinfo_fg, bg = p.fileinfo_bg })
      vim.api.nvim_set_hl(0, "MiniStatuslineLocation", { fg = "#b4b7b4", bg = "#282a2e" })
      restyle("MiniStatuslineInactive", { bg = p.inactive_bg, fg = p.inactive_fg })
      vim.api.nvim_set_hl(0, "LineNr", { fg = "#586394" })
      vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#00e5ff", bold = true })
      vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = "#586394" })
      vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#586394" })
    end,
    keymaps = function()
      vim.keymap.set("n", "<leader>tp", function()
        local cfg = read_pill_palettes()
        if cfg == nil then
          vim.notify(
            "statusline_palettes.toml missing/empty; storm fallback in use",
            vim.log.levels.WARN
          )
          return
        end
        local cur = vim.g.nu_glass_pill_palette or cfg.default or cfg.order[1]
        local idx = 0
        for i, name in ipairs(cfg.order) do
          if name == cur then
            idx = i
            break
          end
        end
        local nxt = cfg.order[idx % #cfg.order + 1]
        vim.g.nu_glass_pill_palette = nxt
        -- Refire only our repaint pass (transparency + decorate).
        vim.api.nvim_exec_autocmds("ColorScheme", {
          group = "ghostty_profile_transparency",
        })
        vim.notify("statusline palette: " .. nxt)
      end, { desc = "Cycle statusline pill palette (nu-glass)" })
    end,
  },
}

local recipe = RECIPES[theme]
if recipe == nil then
  vim.notify(
    ("profile_theme: unknown GHOSTTY_NVIM_THEME %q; using default colors"):format(theme),
    vim.log.levels.WARN
  )
  return {}
end

-- Ghostty's glass/blur shows only through cells nvim leaves unpainted, so
-- transparency = clearing backgrounds on this canonical set. Merge-clear
-- (preserve fg/attrs). Includes the whole gutter: painted LineNr/FoldColumn
-- backgrounds render as an opaque strip against the glass.
local CLEAR_BG = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "FloatBorder",
  "SignColumn",
  "LineNr",
  "CursorLineNr",
  "FoldColumn",
  "EndOfBuffer",
  "StatusLine",
  "StatusLineNC",
  "WinSeparator",
  "MiniStatuslineFilename",
  "MiniStatuslineFileinfo",
  "MiniStatuslineInactive",
}

local function make_transparent()
  for _, group in ipairs(CLEAR_BG) do
    local hl = require("config.hl").snapshot(group, { link = false })
    if hl.bg ~= nil then
      hl.bg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
  end
end

local function repaint()
  make_transparent()
  if recipe.decorate then
    pcall(recipe.decorate)
  end
end

return {
  recipe.plugin,
  name = recipe.name,
  lazy = false,
  priority = 1000, -- like themes.lua: before other start plugins
  config = function()
    -- Pre-set background so nvim's async OSC 11 autodetection writes the
    -- same value it discovers (no-op, no reload flash).
    vim.o.background = recipe.background
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup(
        "ghostty_profile_transparency",
        { clear = true }
      ),
      callback = repaint,
    })
    if recipe.keymaps then
      pcall(recipe.keymaps)
    end
    if recipe.apply then
      -- Setup-style schemes paint directly; :colorscheme never fires, so
      -- run the repaint pass ourselves.
      if not pcall(recipe.apply) then
        vim.notify(
          "profile_theme: recipe apply failed; using default colors",
          vim.log.levels.WARN
        )
      end
      repaint()
    else
      -- First launch in a profile installs the scheme from the network; if
      -- that ever fails, degrade to default colors rather than erroring on
      -- every startup.
      local ok = pcall(vim.cmd.colorscheme, recipe.colorscheme)
      if not ok then
        vim.notify(
          ("profile_theme: colorscheme %q unavailable (offline first launch?); using default colors"):format(
            recipe.colorscheme
          ),
          vim.log.levels.WARN
        )
        repaint()
      end
    end
    vim.o.pumblend = 10 -- popup legibility over glass
  end,
}
