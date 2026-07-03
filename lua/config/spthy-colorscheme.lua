-- spthy-colorscheme.lua
-- Color definitions for Tamarin Protocol Theory syntax highlighting
-- Only the entries referenced by tamarin-colors.lua are kept.

local M = {}

-- Color and style definitions (alphabetically ordered)
M.colors = {
  blueBold                   = { fg = "#89b4fa", bold = true },                                   -- Blue - for linear facts
  blueBoldUnderlined         = { fg = "#89b4fa", bold = true, underline = true },                 -- Same blue with underline for builtin facts
  brownNoStyle               = { fg = "#8B4513" },                                                -- SaddleBrown - for numbers
  brownPlainItalic           = { fg = "#8B4513", bold = false, italic = true },                   -- SaddleBrown italic - for number variables/arities
  darkGoldBold               = { fg = "#908070", bold = true },                                   -- Dark gold - for tuples
  flamingoItalic             = { fg = "#f2cdcd", italic = true, bold = false },                   -- Flamingo - for fresh variables (~k)
  grayItalic                 = { fg = "#777777", italic = true },                                 -- Gray - for comments
  greenItalic                = { fg = "#a6e3a1", italic = true, bold = false },                   -- Green - for public variables ($A)
  hotPink                    = { fg = "#FF1493", italic = true, bold = false, nocombine = true }, -- Deep Pink - for public constants
  maroonItalic               = { fg = "#eba0ac", italic = true, bold = false, nocombine = true }, -- Maroon - for message variables
  mauve                      = { fg = "#cba6f7" },                                                -- Mauve - for keywords
  mediumMagentaBold          = { fg = "#FF5FFF", bold = true },                                   -- Medium Magenta - for logical operators
  peachBold                  = { fg = "#fab387", bold = true },                                   -- Peach - for types and rule names
  peachItalic                = { fg = "#fab387", italic = true },                                 -- Peach - for regular variables
  pink                       = { fg = "#f5c2e7" },                                                -- Pink - for action brackets and period
  pinkBold                   = { fg = "#f5c2e7", bold = true },                                   -- Pink - for action facts
  pinkPlain                  = { fg = "#FFC0CB", italic = false },                                -- Pink - for type qualifiers
  redBold                    = { fg = "#f38ba8", bold = true },                                   -- Red - for persistent facts (!Ltk)
  redBoldUnderlined          = { fg = "#f38ba8", bold = true, underline = true },                 -- Red with underline - for errors
  redItalic                  = { fg = "#f38ba8", italic = true },                                 -- Red - for function arities
  skyItalic                  = { fg = "#89dceb", italic = true },                                 -- Sky - for temporal variables (#i)
  slateGrayBold              = { fg = "#708090", bold = true },                                   -- Slate Gray - for operators with bold
  slateGrayPlain             = { fg = "#708090" },                                                -- Slate Gray - for punctuation
  yellowBoldItalic           = { fg = "#f9e2af", bold = true, italic = true },                    -- Yellow - for functions and macros
  yellowBoldItalicUnderlined = { fg = "#f9e2af", bold = true, italic = true, underline = true },  -- Yellow underlined - for builtin functions
}

return M
