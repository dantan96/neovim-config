-- spthy-colorscheme.lua
-- Color definitions for Tamarin Protocol Theory syntax highlighting
-- Deleted:
-- blueBold                                 = { fg = "#1E90FF", bold = true },                       -- Dodger Blue - vibrant blue for linear facts
-- blueBoldUnderlined                       = { fg = "#1E90FF", bold = true, underline = true },     -- Same blue with underline for builtin facts
-- green                                    = { fg = "#00cc33", bold = false },                      -- Bright green for public variables, rich and forest-like
-- red                                      = { fg = "#FF3030", bold = false, italic = false },      -- Pure Red - with bold and italic
-- redBold                                  = { fg = "#FF3030", bold = true },                       -- Firebrick Red - for persistent facts (!Ltk)
-- redBoldItalic                            = { fg = "#FF3030", bold = true, italic = true },        -- Pure Red - with bold and italic
-- redItalic                                = { fg = "#FF3030", bold = false, italic = true },       -- Pure Red - with bold and italic
-- redBoldUnderlined                        = { fg = "#FF3030", bold = true, underline = true },     -- Red with underline - for errors
-- redItalicUnderlined                      = { fg = "#FF3030", bold = false, italic = true, underline = true }, -- Pure Red - with bold and italic

local M = {}

-- Color and style definitions (alphabetically ordered)
M.colors = {
  -- Base colors (alphabetical by name)
  brightBlueBold                           = { fg = "#006bff", bold = true },                                     -- Dodger Blue - vibrant blue for linear facts
  brightBlue                               = { fg = "#006bff", bold = false },                                    -- Dodger Blue - vibrant blue for linear facts
  brightBlueUnderlined                     = { fg = "#006bff", bold = false, underline = true },                  -- Same blue with underline for builtin facts
  brownPlain                               = { fg = "#8B4513", bold = false },                                    -- SaddleBrown - for number variables
  brownPlainItalic                         = { fg = "#8B4513", bold = false, italic = true },                     -- SaddleBrown italic - for number variables/arities
  brownNoStyle                             = { fg = "#8B4513" },                                                  -- SaddleBrown - for numbers
  deepBlueGreen                            = { fg = "#006B5B" },                                                  -- Deep teal/blue-green for public variables
  deeperPurple                             = { fg = "#8877BB", bold = false },                                    -- Muted purple for preprocessor identifiers
  deepGreen                                = { fg = "#006400", bold = false },                                    -- Deep green for public variables, rich and forest-like
  mediumGreen                              = { fg = "#04a12b", bold = false },                                    -- Medium green for public variables, rich and forest-like
  goldBold                                 = { fg = "#FFD700", bold = true },                                     -- Gold - for rule/theory names with bold
  goldBoldItalic                           = { fg = "#FFD700", bold = true, italic = true },                      -- Gold - for rule/theory names with bold
  goldBoldUnderlined                       = { fg = "#FFD700", bold = true, underline = true },                   -- Gold with underline for builtins
  goldBoldUnderdotted                      = { fg = "#FFD700", bold = true, underdotted = true },                 -- Gold with underline for builtins
  goldItalic                               = { fg = "#FFD700", bold = false, italic = true },                     -- Gold with italic for theory names
  darkGold                                 = { fg = "#908070", bold = false },                                    -- Gold - for rule/theory names with bold
  darkGoldBold                             = { fg = "#908070", bold = true },                                     -- Gold - for rule/theory names with bold
  lightGold                                = { fg = "#FFE766", bold = false },                                    -- Gold - for rule/theory names with bold
  lightGoldBold                            = { fg = "#FFE766", bold = true },                                     -- Gold - for rule/theory names with bold
  lightGoldBoldUnderlined                  = { fg = "#FFE766", bold = true, underline = true },                   -- Gold with underline for builtins
  lightGoldBoldUnderdotted                 = { fg = "#FFE766", bold = true, underdotted = true },                 -- Gold with underline for builtins
  lightGoldItalicUnderdotted               = { fg = "#FFE766", bold = false, italic = true, underdotted = true }, -- Gold with underline for builtins
  lightGoldItalic                          = { fg = "#FFE766", bold = false, italic = true },                     -- Gold with italic for theory names
  grayItalic                               = { fg = "#777777", italic = true },                                   -- Gray - for comments
  grayPlain                                = { fg = "#888888", bold = false },                                    -- Gray - for logical operators
  hotPink                                  = { fg = "#FF1493", italic = true, bold = false, nocombine = true },   -- Deep Pink - for public constants
  hotPinkBold                              = { fg = "#FF1493", bold = true },                                     -- Deep Pink - for public constants
  hotPinkPlain                             = { fg = "#FF69B4", bold = false },                                    -- Hot Pink - for fresh variables (~k)
  lightPinkPlain                           = { fg = "#FFB6C1", bold = false },                                    -- Light Pink - for action facts
  lilacBold                                = { fg = "#D7A0FF", bold = true },                                     -- Lilac - for keyword quantifiers
  magentaBold                              = { fg = "#FF00FF", bold = true },                                     -- Magenta - for keywords
  mediumMagentaBold                        = { fg = "#FF5FFF", bold = true },                                     -- Medium Magenta - for module keywords
  mediumPurple                             = { fg = "#9370DB", italic = false },                                  -- Medium Purple - for rule structure
  mutedPurple                              = { fg = "#9966CC", bold = false },                                    -- Muted Purple - for preprocessor
  orangeNoStyle                            = { fg = "#FF8C00" },                                                  -- Dark Orange - for regular variables
  orangePlain                              = { fg = "#FF8C00", bold = false },                                    -- Dark Orange - for message variables
  orangeBold                               = { fg = "#FF8C00", bold = true },                                     -- Dark Orange - for message variables
  orangeItalic                             = { fg = "#FF8C00", bold = false, italic = true },                     -- Dark Orange - for message variables
  orangeBoldUnderlined                     = { fg = "#FF8C00", bold = true, underline = true },                   -- Dark Orange - for message variables
  orangeItalicUnderlined                   = { fg = "#FF8C00", italic = true, underline = true },                 -- Dark Orange - for message variables
  orchidItalic                             = { fg = "#DA70D6", italic = true },                                   -- Orchid - for string constants
  orchidPlain                              = { fg = "#DA70D6" },                                                  -- Orchid - for constants
  pinkPlain                                = { fg = "#FFC0CB", italic = false },                                  -- Pink - for type qualifiers
  purplePlain                              = { fg = "#AA88FF" },                                                  -- Purple - for exponentiation
  royalBlue                                = { fg = "#4169E1", italic = false },                                  -- Royal Blue - for rule conclusions
  royalBlueUnderlined                      = { fg = "#4169E1", italic = false, underline = true },                -- Royal Blue - for rule conclusions
  royalBlueItalicUnderlined                = { fg = "#4169E1", italic = true, underline = true },                 -- Royal Blue - for rule conclusions
  skyBluePlain                             = { fg = "#00BFFF", bold = false },                                    -- Deep Sky Blue - for temporal variables (#i)
  slateBlue                                = { fg = "#6A5ACD", italic = false },                                  -- Slate Blue - for rule premises
  slateGrayBold                            = { fg = "#708090", bold = true },                                     -- Slate Gray - for operators with bold
  slateGrayPlain                           = { fg = "#708090" },                                                  -- Slate Gray - for punctuation
  tomatoPlain                              = { fg = "#FF6347", bold = false },                                    -- Tomato - for functions with italic
  tomatoItalic                             = { fg = "#FF6347", italic = true, bold = false },                     -- Tomato - for functions with italic
  tomatoItalicUnderlined                   = { fg = "#FF6347", italic = true, bold = false, underline = true },   -- Tomato - for functions with italic
  rosewater                                = { fg = "#f5e0dc" },
  rosewaterUnderdotted                     = { fg = "#f5e0dc", underdotted = true },
  rosewaterUnderlined                      = { fg = "#f5e0dc", underline = true },
  rosewaterUnderlinedUnderdotted           = { fg = "#f5e0dc", underline = true, underdotted = true },
  rosewaterItalic                          = { fg = "#f5e0dc", italic = true },
  rosewaterItalicUnderdotted               = { fg = "#f5e0dc", italic = true, underdotted = true },
  rosewaterItalicUnderlined                = { fg = "#f5e0dc", italic = true, underline = true },
  rosewaterItalicUnderlinedUnderdotted     = { fg = "#f5e0dc", italic = true, underline = true, underdotted = true },
  rosewaterBold                            = { fg = "#f5e0dc", bold = true },
  rosewaterBoldUnderdotted                 = { fg = "#f5e0dc", bold = true, underdotted = true },
  rosewaterBoldUnderlined                  = { fg = "#f5e0dc", bold = true, underline = true },
  rosewaterBoldUnderlinedUnderdotted       = { fg = "#f5e0dc", bold = true, underline = true, underdotted = true },
  rosewaterBoldItalic                      = { fg = "#f5e0dc", bold = true, italic = true },
  rosewaterBoldItalicUnderdotted           = { fg = "#f5e0dc", bold = true, italic = true, underdotted = true },
  rosewaterBoldItalicUnderlined            = { fg = "#f5e0dc", bold = true, italic = true, underline = true },
  rosewaterBoldItalicUnderlinedUnderdotted = { fg = "#f5e0dc", bold = true, italic = true, underline = true, underdotted = true },
  flamingo                                 = { fg = "#f2cdcd" },
  flamingoUnderdotted                      = { fg = "#f2cdcd", underdotted = true },
  flamingoUnderlined                       = { fg = "#f2cdcd", underline = true },
  flamingoUnderlinedUnderdotted            = { fg = "#f2cdcd", underline = true, underdotted = true },
  flamingoItalic                           = { fg = "#f2cdcd", italic = true, bold = false },
  flamingoItalicUnderdotted                = { fg = "#f2cdcd", italic = true, underdotted = true },
  flamingoItalicUnderlined                 = { fg = "#f2cdcd", italic = true, underline = true },
  flamingoItalicUnderlinedUnderdotted      = { fg = "#f2cdcd", italic = true, underline = true, underdotted = true },
  flamingoBold                             = { fg = "#f2cdcd", bold = true },
  flamingoBoldUnderdotted                  = { fg = "#f2cdcd", bold = true, underdotted = true },
  flamingoBoldUnderlined                   = { fg = "#f2cdcd", bold = true, underline = true },
  flamingoBoldUnderlinedUnderdotted        = { fg = "#f2cdcd", bold = true, underline = true, underdotted = true },
  flamingoBoldItalic                       = { fg = "#f2cdcd", bold = true, italic = true },
  flamingoBoldItalicUnderdotted            = { fg = "#f2cdcd", bold = true, italic = true, underdotted = true },
  flamingoBoldItalicUnderlined             = { fg = "#f2cdcd", bold = true, italic = true, underline = true },
  flamingoBoldItalicUnderlinedUnderdotted  = { fg = "#f2cdcd", bold = true, italic = true, underline = true, underdotted = true },
  pink                                     = { fg = "#f5c2e7" },
  pinkUnderdotted                          = { fg = "#f5c2e7", underdotted = true },
  pinkUnderlined                           = { fg = "#f5c2e7", underline = true },
  pinkUnderlinedUnderdotted                = { fg = "#f5c2e7", underline = true, underdotted = true },
  pinkItalic                               = { fg = "#f5c2e7", italic = true },
  pinkItalicUnderdotted                    = { fg = "#f5c2e7", italic = true, underdotted = true },
  pinkItalicUnderlined                     = { fg = "#f5c2e7", italic = true, underline = true },
  pinkItalicUnderlinedUnderdotted          = { fg = "#f5c2e7", italic = true, underline = true, underdotted = true },
  pinkBold                                 = { fg = "#f5c2e7", bold = true },
  pinkBoldUnderdotted                      = { fg = "#f5c2e7", bold = true, underdotted = true },
  pinkBoldUnderlined                       = { fg = "#f5c2e7", bold = true, underline = true },
  pinkBoldUnderlinedUnderdotted            = { fg = "#f5c2e7", bold = true, underline = true, underdotted = true },
  pinkBoldItalic                           = { fg = "#f5c2e7", bold = true, italic = true },
  pinkBoldItalicUnderdotted                = { fg = "#f5c2e7", bold = true, italic = true, underdotted = true },
  pinkBoldItalicUnderlined                 = { fg = "#f5c2e7", bold = true, italic = true, underline = true },
  pinkBoldItalicUnderlinedUnderdotted      = { fg = "#f5c2e7", bold = true, italic = true, underline = true, underdotted = true },
  mauve                                    = { fg = "#cba6f7" },
  mauveUnderdotted                         = { fg = "#cba6f7", underdotted = true },
  mauveUnderlined                          = { fg = "#cba6f7", underline = true },
  mauveUnderlinedUnderdotted               = { fg = "#cba6f7", underline = true, underdotted = true },
  mauveItalic                              = { fg = "#cba6f7", italic = true },
  mauveItalicUnderdotted                   = { fg = "#cba6f7", italic = true, underdotted = true },
  mauveItalicUnderlined                    = { fg = "#cba6f7", italic = true, underline = true },
  mauveItalicUnderlinedUnderdotted         = { fg = "#cba6f7", italic = true, underline = true, underdotted = true },
  mauveBold                                = { fg = "#cba6f7", bold = true },
  mauveBoldUnderdotted                     = { fg = "#cba6f7", bold = true, underdotted = true },
  mauveBoldUnderlined                      = { fg = "#cba6f7", bold = true, underline = true },
  mauveBoldUnderlinedUnderdotted           = { fg = "#cba6f7", bold = true, underline = true, underdotted = true },
  mauveBoldItalic                          = { fg = "#cba6f7", bold = true, italic = true },
  mauveBoldItalicUnderdotted               = { fg = "#cba6f7", bold = true, italic = true, underdotted = true },
  mauveBoldItalicUnderlined                = { fg = "#cba6f7", bold = true, italic = true, underline = true },
  mauveBoldItalicUnderlinedUnderdotted     = { fg = "#cba6f7", bold = true, italic = true, underline = true, underdotted = true },
  red                                      = { fg = "#f38ba8" },
  redUnderdotted                           = { fg = "#f38ba8", underdotted = true },
  redUnderlined                            = { fg = "#f38ba8", underline = true },
  redUnderlinedUnderdotted                 = { fg = "#f38ba8", underline = true, underdotted = true },
  redItalic                                = { fg = "#f38ba8", italic = true },
  redItalicUnderdotted                     = { fg = "#f38ba8", italic = true, underdotted = true },
  redItalicUnderlined                      = { fg = "#f38ba8", italic = true, underline = true },
  redItalicUnderlinedUnderdotted           = { fg = "#f38ba8", italic = true, underline = true, underdotted = true },
  redBold                                  = { fg = "#f38ba8", bold = true },
  redBoldUnderdotted                       = { fg = "#f38ba8", bold = true, underdotted = true },
  redBoldUnderlined                        = { fg = "#f38ba8", bold = true, underline = true },
  redBoldUnderlinedUnderdotted             = { fg = "#f38ba8", bold = true, underline = true, underdotted = true },
  redBoldItalic                            = { fg = "#f38ba8", bold = true, italic = true },
  redBoldItalicUnderdotted                 = { fg = "#f38ba8", bold = true, italic = true, underdotted = true },
  redBoldItalicUnderlined                  = { fg = "#f38ba8", bold = true, italic = true, underline = true },
  redBoldItalicUnderlinedUnderdotted       = { fg = "#f38ba8", bold = true, italic = true, underline = true, underdotted = true },
  maroon                                   = { fg = "#eba0ac", bold = false, },
  maroonUnderdotted                        = { fg = "#eba0ac", underdotted = true },
  maroonUnderlined                         = { fg = "#eba0ac", underline = true },
  maroonUnderlinedUnderdotted              = { fg = "#eba0ac", underline = true, underdotted = true },
  maroonItalic                             = { fg = "#eba0ac", italic = true, bold = false, nocombine = true },
  maroonItalicUnderdotted                  = { fg = "#eba0ac", italic = true, underdotted = true },
  maroonItalicUnderlined                   = { fg = "#eba0ac", italic = true, underline = true },
  maroonItalicUnderlinedUnderdotted        = { fg = "#eba0ac", italic = true, underline = true, underdotted = true },
  maroonBold                               = { fg = "#eba0ac", bold = true },
  maroonBoldUnderdotted                    = { fg = "#eba0ac", bold = true, underdotted = true },
  maroonBoldUnderlined                     = { fg = "#eba0ac", bold = true, underline = true },
  maroonBoldUnderlinedUnderdotted          = { fg = "#eba0ac", bold = true, underline = true, underdotted = true },
  maroonBoldItalic                         = { fg = "#eba0ac", bold = true, italic = true },
  maroonBoldItalicUnderdotted              = { fg = "#eba0ac", bold = true, italic = true, underdotted = true },
  maroonBoldItalicUnderlined               = { fg = "#eba0ac", bold = true, italic = true, underline = true },
  maroonBoldItalicUnderlinedUnderdotted    = { fg = "#eba0ac", bold = true, italic = true, underline = true, underdotted = true },
  peach                                    = { fg = "#fab387" },
  peachUnderdotted                         = { fg = "#fab387", underdotted = true },
  peachUnderlined                          = { fg = "#fab387", underline = true },
  peachUnderlinedUnderdotted               = { fg = "#fab387", underline = true, underdotted = true },
  peachItalic                              = { fg = "#fab387", italic = true },
  peachItalicUnderdotted                   = { fg = "#fab387", italic = true, underdotted = true },
  peachItalicUnderlined                    = { fg = "#fab387", italic = true, underline = true },
  peachItalicUnderlinedUnderdotted         = { fg = "#fab387", italic = true, underline = true, underdotted = true },
  peachBold                                = { fg = "#fab387", bold = true },
  peachBoldUnderdotted                     = { fg = "#fab387", bold = true, underdotted = true },
  peachBoldUnderlined                      = { fg = "#fab387", bold = true, underline = true },
  peachBoldUnderlinedUnderdotted           = { fg = "#fab387", bold = true, underline = true, underdotted = true },
  peachBoldItalic                          = { fg = "#fab387", bold = true, italic = true },
  peachBoldItalicUnderdotted               = { fg = "#fab387", bold = true, italic = true, underdotted = true },
  peachBoldItalicUnderlined                = { fg = "#fab387", bold = true, italic = true, underline = true },
  peachBoldItalicUnderlinedUnderdotted     = { fg = "#fab387", bold = true, italic = true, underline = true, underdotted = true },
  yellow                                   = { fg = "#f9e2af" },
  yellowUnderdotted                        = { fg = "#f9e2af", underdotted = true },
  yellowUnderlined                         = { fg = "#f9e2af", underline = true },
  yellowUnderlinedUnderdotted              = { fg = "#f9e2af", underline = true, underdotted = true },
  yellowItalic                             = { fg = "#f9e2af", italic = true },
  yellowItalicUnderdotted                  = { fg = "#f9e2af", italic = true, underdotted = true },
  yellowItalicUnderlined                   = { fg = "#f9e2af", italic = true, underline = true },
  yellowItalicUnderlinedUnderdotted        = { fg = "#f9e2af", italic = true, underline = true, underdotted = true },
  yellowBold                               = { fg = "#f9e2af", bold = true },
  yellowBoldUnderdotted                    = { fg = "#f9e2af", bold = true, underdotted = true },
  yellowBoldUnderlined                     = { fg = "#f9e2af", bold = true, underline = true },
  yellowBoldUnderlinedUnderdotted          = { fg = "#f9e2af", bold = true, underline = true, underdotted = true },
  yellowBoldItalic                         = { fg = "#f9e2af", bold = true, italic = true },
  yellowBoldItalicUnderdotted              = { fg = "#f9e2af", bold = true, italic = true, underdotted = true },
  yellowBoldItalicUnderlined               = { fg = "#f9e2af", bold = true, italic = true, underline = true },
  yellowBoldItalicUnderlinedUnderdotted    = { fg = "#f9e2af", bold = true, italic = true, underline = true, underdotted = true },
  green                                    = { fg = "#a6e3a1", bold = false },
  greenUnderdotted                         = { fg = "#a6e3a1", underdotted = true },
  greenUnderlined                          = { fg = "#a6e3a1", underline = true },
  greenUnderlinedUnderdotted               = { fg = "#a6e3a1", underline = true, underdotted = true },
  greenItalic                              = { fg = "#a6e3a1", italic = true, bold = false },
  greenItalicUnderdotted                   = { fg = "#a6e3a1", italic = true, underdotted = true },
  greenItalicUnderlined                    = { fg = "#a6e3a1", italic = true, underline = true },
  greenItalicUnderlinedUnderdotted         = { fg = "#a6e3a1", italic = true, underline = true, underdotted = true },
  greenBold                                = { fg = "#a6e3a1", bold = true },
  greenBoldUnderdotted                     = { fg = "#a6e3a1", bold = true, underdotted = true },
  greenBoldUnderlined                      = { fg = "#a6e3a1", bold = true, underline = true },
  greenBoldUnderlinedUnderdotted           = { fg = "#a6e3a1", bold = true, underline = true, underdotted = true },
  greenBoldItalic                          = { fg = "#a6e3a1", bold = true, italic = true },
  greenBoldItalicUnderdotted               = { fg = "#a6e3a1", bold = true, italic = true, underdotted = true },
  greenBoldItalicUnderlined                = { fg = "#a6e3a1", bold = true, italic = true, underline = true },
  greenBoldItalicUnderlinedUnderdotted     = { fg = "#a6e3a1", bold = true, italic = true, underline = true, underdotted = true },
  teal                                     = { fg = "#94e2d5" },
  tealUnderdotted                          = { fg = "#94e2d5", underdotted = true },
  tealUnderlined                           = { fg = "#94e2d5", underline = true },
  tealUnderlinedUnderdotted                = { fg = "#94e2d5", underline = true, underdotted = true },
  tealItalic                               = { fg = "#94e2d5", italic = true },
  tealItalicUnderdotted                    = { fg = "#94e2d5", italic = true, underdotted = true },
  tealItalicUnderlined                     = { fg = "#94e2d5", italic = true, underline = true },
  tealItalicUnderlinedUnderdotted          = { fg = "#94e2d5", italic = true, underline = true, underdotted = true },
  tealBold                                 = { fg = "#94e2d5", bold = true },
  tealBoldUnderdotted                      = { fg = "#94e2d5", bold = true, underdotted = true },
  tealBoldUnderlined                       = { fg = "#94e2d5", bold = true, underline = true },
  tealBoldUnderlinedUnderdotted            = { fg = "#94e2d5", bold = true, underline = true, underdotted = true },
  tealBoldItalic                           = { fg = "#94e2d5", bold = true, italic = true },
  tealBoldItalicUnderdotted                = { fg = "#94e2d5", bold = true, italic = true, underdotted = true },
  tealBoldItalicUnderlined                 = { fg = "#94e2d5", bold = true, italic = true, underline = true },
  tealBoldItalicUnderlinedUnderdotted      = { fg = "#94e2d5", bold = true, italic = true, underline = true, underdotted = true },
  sky                                      = { fg = "#89dceb" },
  skyUnderdotted                           = { fg = "#89dceb", underdotted = true },
  skyUnderlined                            = { fg = "#89dceb", underline = true },
  skyUnderlinedUnderdotted                 = { fg = "#89dceb", underline = true, underdotted = true },
  skyItalic                                = { fg = "#89dceb", italic = true },
  skyItalicUnderdotted                     = { fg = "#89dceb", italic = true, underdotted = true },
  skyItalicUnderlined                      = { fg = "#89dceb", italic = true, underline = true },
  skyItalicUnderlinedUnderdotted           = { fg = "#89dceb", italic = true, underline = true, underdotted = true },
  skyBold                                  = { fg = "#89dceb", bold = true },
  skyBoldUnderdotted                       = { fg = "#89dceb", bold = true, underdotted = true },
  skyBoldUnderlined                        = { fg = "#89dceb", bold = true, underline = true },
  skyBoldUnderlinedUnderdotted             = { fg = "#89dceb", bold = true, underline = true, underdotted = true },
  skyBoldItalic                            = { fg = "#89dceb", bold = true, italic = true },
  skyBoldItalicUnderdotted                 = { fg = "#89dceb", bold = true, italic = true, underdotted = true },
  skyBoldItalicUnderlined                  = { fg = "#89dceb", bold = true, italic = true, underline = true },
  skyBoldItalicUnderlinedUnderdotted       = { fg = "#89dceb", bold = true, italic = true, underline = true, underdotted = true },
  sapphire                                 = { fg = "#74c7ec" },
  sapphireUnderdotted                      = { fg = "#74c7ec", underdotted = true },
  sapphireUnderlined                       = { fg = "#74c7ec", underline = true },
  sapphireUnderlinedUnderdotted            = { fg = "#74c7ec", underline = true, underdotted = true },
  sapphireItalic                           = { fg = "#74c7ec", italic = true },
  sapphireItalicUnderdotted                = { fg = "#74c7ec", italic = true, underdotted = true },
  sapphireItalicUnderlined                 = { fg = "#74c7ec", italic = true, underline = true },
  sapphireItalicUnderlinedUnderdotted      = { fg = "#74c7ec", italic = true, underline = true, underdotted = true },
  sapphireBold                             = { fg = "#74c7ec", bold = true },
  sapphireBoldUnderdotted                  = { fg = "#74c7ec", bold = true, underdotted = true },
  sapphireBoldUnderlined                   = { fg = "#74c7ec", bold = true, underline = true },
  sapphireBoldUnderlinedUnderdotted        = { fg = "#74c7ec", bold = true, underline = true, underdotted = true },
  sapphireBoldItalic                       = { fg = "#74c7ec", bold = true, italic = true },
  sapphireBoldItalicUnderdotted            = { fg = "#74c7ec", bold = true, italic = true, underdotted = true },
  sapphireBoldItalicUnderlined             = { fg = "#74c7ec", bold = true, italic = true, underline = true },
  sapphireBoldItalicUnderlinedUnderdotted  = { fg = "#74c7ec", bold = true, italic = true, underline = true, underdotted = true },
  blue                                     = { fg = "#89b4fa" },
  blueUnderdotted                          = { fg = "#89b4fa", underdotted = true },
  blueUnderlined                           = { fg = "#89b4fa", underline = true },
  blueUnderlinedUnderdotted                = { fg = "#89b4fa", underline = true, underdotted = true },
  blueItalic                               = { fg = "#89b4fa", italic = true },
  blueItalicUnderdotted                    = { fg = "#89b4fa", italic = true, underdotted = true },
  blueItalicUnderlined                     = { fg = "#89b4fa", italic = true, underline = true },
  blueItalicUnderlinedUnderdotted          = { fg = "#89b4fa", italic = true, underline = true, underdotted = true },
  blueBold                                 = { fg = "#89b4fa", bold = true },
  blueBoldUnderdotted                      = { fg = "#89b4fa", bold = true, underdotted = true },
  blueBoldUnderlined                       = { fg = "#89b4fa", bold = true, underline = true },
  blueBoldUnderlinedUnderdotted            = { fg = "#89b4fa", bold = true, underline = true, underdotted = true },
  blueBoldItalic                           = { fg = "#89b4fa", bold = true, italic = true },
  blueBoldItalicUnderdotted                = { fg = "#89b4fa", bold = true, italic = true, underdotted = true },
  blueBoldItalicUnderlined                 = { fg = "#89b4fa", bold = true, italic = true, underline = true },
  blueBoldItalicUnderlinedUnderdotted      = { fg = "#89b4fa", bold = true, italic = true, underline = true, underdotted = true },
  lavender                                 = { fg = "#b4befe" },
  lavenderUnderdotted                      = { fg = "#b4befe", underdotted = true },
  lavenderUnderlined                       = { fg = "#b4befe", underline = true },
  lavenderUnderlinedUnderdotted            = { fg = "#b4befe", underline = true, underdotted = true },
  lavenderItalic                           = { fg = "#b4befe", italic = true },
  lavenderItalicUnderdotted                = { fg = "#b4befe", italic = true, underdotted = true },
  lavenderItalicUnderlined                 = { fg = "#b4befe", italic = true, underline = true },
  lavenderItalicUnderlinedUnderdotted      = { fg = "#b4befe", italic = true, underline = true, underdotted = true },
  lavenderBold                             = { fg = "#b4befe", bold = true },
  lavenderBoldUnderdotted                  = { fg = "#b4befe", bold = true, underdotted = true },
  lavenderBoldUnderlined                   = { fg = "#b4befe", bold = true, underline = true },
  lavenderBoldUnderlinedUnderdotted        = { fg = "#b4befe", bold = true, underline = true, underdotted = true },
  lavenderBoldItalic                       = { fg = "#b4befe", bold = true, italic = true },
  lavenderBoldItalicUnderdotted            = { fg = "#b4befe", bold = true, italic = true, underdotted = true },
  lavenderBoldItalicUnderlined             = { fg = "#b4befe", bold = true, italic = true, underline = true },
  lavenderBoldItalicUnderlinedUnderdotted  = { fg = "#b4befe", bold = true, italic = true, underline = true, underdotted = true },
  text                                     = { fg = "#cdd6f4" },
  textUnderdotted                          = { fg = "#cdd6f4", underdotted = true },
  textUnderlined                           = { fg = "#cdd6f4", underline = true },
  textUnderlinedUnderdotted                = { fg = "#cdd6f4", underline = true, underdotted = true },
  textItalic                               = { fg = "#cdd6f4", italic = true },
  textItalicUnderdotted                    = { fg = "#cdd6f4", italic = true, underdotted = true },
  textItalicUnderlined                     = { fg = "#cdd6f4", italic = true, underline = true },
  textItalicUnderlinedUnderdotted          = { fg = "#cdd6f4", italic = true, underline = true, underdotted = true },
  textBold                                 = { fg = "#cdd6f4", bold = true },
  textBoldUnderdotted                      = { fg = "#cdd6f4", bold = true, underdotted = true },
  subtext1                                 = { bg = "#bac2de" },
  subtext0                                 = { bg = "#a6adc8" },
  overlay2                                 = { bg = "#9399b2" },
  overlay1                                 = { bg = "#7f849c" },
  overlay0                                 = { bg = "#6c7086" },
  surface2                                 = { bg = "#585b70" },
  surface1                                 = { bg = "#45475a" },
  surface0                                 = { bg = "#313244" },
  base                                     = { bg = "#1e1e2e" },
  mantle                                   = { bg = "#181825" },
  crust                                    = { bg = "#11111b" }
}

-- Optional: provide a function to create a new color style
-- This makes it easier to combine colors with styles
function M.create_style(hex_color, styles)
  styles = styles or {}
  local style = { fg = hex_color }

  -- Apply optional styles
  if styles.bold then style.bold = true end
  if styles.italic then style.italic = true end
  if styles.underline then style.underline = true end
  if styles.undercurl then style.undercurl = true end
  if styles.strikethrough then style.strikethrough = true end

  return style
end

return M
