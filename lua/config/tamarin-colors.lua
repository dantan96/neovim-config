-- Tamarin Syntax Highlighting Colors
-- Colors to apply to TreeSitter captures defined in highlights.scm

local M = {}

-- Function to set up highlighting
function M.setup()
  -- Load color definitions from colorscheme file
  local colors = require('config.spthy-colorscheme').colors

  -- -- Define highlighting groups specific to Tamarin/spthy
  M.highlights = {
    --   ---------------------------------------------------
    --   -- KEYWORDS AND STRUCTURE
    --   ---------------------------------------------------
    ["@keyword"]                              = colors.mauve,     -- Keywords: theory, begin, end, rule, lemma, builtins, restriction, functions, equations
    ["@keyword.trace_quantifier"]             = colors.mauve,     -- Quantifiers: All, Ex, ∀, ∃
    ["@keyword.quantifier"]                   = colors.mauve,     -- Quantifiers: "exists-trace", "all-traces"
    ["@keyword.module"]                       = colors.mauve,     -- Module keywords: builtins, functions, predicates, options
    ["@keyword.function"]                     = colors.mauve,     -- Function keywords: rule, lemma, axiom, restriction
    ["@keyword.tactic"]                       = colors.mauve,     -- Tactic keywords: tactic, presort, prio, deprio
    ["@keyword.tactic.value"]                 = colors.mauve,     -- Tactic values: direct, sorry, simplify, solve, contradiction
    ["@keyword.macro"]                        = colors.mauve,     -- Macro keywords: macros, let, in
    ["@preproc"]                              = colors.mauve,     -- Preprocessor: #ifdef, #endif, #define, #include
    ["@preproc.identifier"]                   = colors.mauve,     -- Preprocessor identifiers: PREPROCESSING, DEBUG, etc.

    ["@structure"]                            = colors.peachBold, -- Structure elements: protocol, for, accounts
    ["@type"]                                 = colors.peachBold, -- Theory/type names: name in 'theory <n>'
    ["@function.rule"]                        = colors.peachBold, -- Rule/lemma names: name in 'rule <n>:', 'lemma <n>:'
    ["@type.builtin"]                         = colors.peachBold, -- Builtins: diffie-hellman, hashing, symmetric-encryption, signing, etc.
    ["@type.qualifier"]                       = colors.pinkPlain, -- Type qualifiers: private, public, fresh

    ---------------------------------------------------
    -- VARIABLES - WITH DISTINCT CONTRASTING COLORS
    ---------------------------------------------------
    ["@variable"]                             = colors.peachItalic,      -- Regular variables: general identifiers without special prefix
    ["@variable.public"]                      = colors.greenItalic,      -- Public variables: $A, A:pub - deep forest green as requested
    ["@variable.fresh"]                       = colors.flamingoItalic,   -- Fresh variables: ~k, ~id, ~ltk - distinctive hot pink
    ["@variable.temporal"]                    = colors.skyItalic,        -- Temporal variables: #i, #j - vibrant sky blue
    ["@variable.message"]                     = colors.maroonItalic,     -- Message variables: no prefix or :msg - orange shade
    ["@variable.number"]                      = colors.brownPlainItalic, -- Number variables/arities: 2 in f/2 - earthy brown

    ---------------------------------------------------
    -- FACTS - WITH DISTINCT CONTRASTING COLORS
    ---------------------------------------------------
    ["@fact.persistent"]                      = colors.redBold,            -- Persistent facts: !Ltk, !Pk, !User - bold red as requested
    ["@fact.linear"]                          = colors.blueBold,           -- Linear facts: standard facts without ! prefix - bold blue
    ["@fact.builtin"]                         = colors.blueBoldUnderlined, -- Built-in facts: Fr, In, Out, K - same color as linear but underlined
    ["@fact.action"]                          = colors.pinkBold,           -- Action facts: inside --[ and ]-> - light pink for contrast

    ---------------------------------------------------
    -- FUNCTIONS AND MACROS
    ---------------------------------------------------
    ["@function"]                             = colors.yellowBoldItalic,           -- Regular functions: f(), pk(), h() - tomato with italic
    ["@function.arity"]                       = colors.redItalic,                  -- Regular functions: f(), pk(), h() - tomato with italic
    ["@function.builtin"]                     = colors.yellowBoldItalicUnderlined, -- Regular functions: f(), pk(), h() - tomato with italic
    ["@function.macro"]                       = colors.yellowBoldItalic,           -- Macro names: names defined in macro declarations
    ["@function.macro.call"]                  = colors.yellowBoldItalic,           -- Macro use in code: using a defined macro

    ---------------------------------------------------
    -- BRACKETS, PUNCTUATION, OPERATORS
    ---------------------------------------------------
    ["@operator.action"]                      = colors.pink,              -- Action brackets: --[ and ]->
    ["@operator.actionless"]                  = colors.pink,              -- Action brackets: --[ and ]->
    ["@operator.exponentiation"]              = colors.slateGrayBold,     -- Exponentiation: ^
    ["@operator.logical"]                     = colors.mediumMagentaBold, -- Logical operators: &, |, not
    ["@operator.implies"]                     = colors.mediumMagentaBold, -- Logical operator: ==>
    ["@operator.at"]                          = colors.pink,              -- At operator: @
    ["@operator.lessthan"]                    = colors.pink,              -- At operator: <
    ["@operator.assignment"]                  = colors.slateGrayPlain,    -- Assignment operators: = in let statements
    ["@punctuation.bracket.square"]           = colors.slateGrayPlain,    -- Regular brackets: (), [], <>
    ["@punctuation.bracket.round"]            = colors.slateGrayPlain,    -- Regular brackets: (), [], <>
    ["@punctuation.delimiter.period"]         = colors.pink,              -- Punctuation: . (just the fullstop)
    ["@punctuation.delimiter.semicolon"]      = colors.slateGrayPlain,    -- Punctuation: ;
    ["@punctuation.delimiter.colon"]          = colors.slateGrayPlain,    -- Punctuation: :
    ["@punctuation.delimiter.comma"]          = colors.slateGrayPlain,    -- Punctuation: , (outside tuples)
    ["@tuple"]                                = colors.darkGoldBold,      -- Regular brackets: (), [], <>

    ---------------------------------------------------
    -- NUMBERS, CONSTANTS, STRINGS
    ---------------------------------------------------
    ["@number"]                               = colors.brownNoStyle, -- Numbers: 1, 2, 3
    ["@public.constant"]                      = colors.hotPink,      -- Public constants: 'g', 'pk', etc. (in single quotes)
    ["@public.constant.tuple"]                = colors.hotPink,      -- Public constants: 'g', 'pk', etc. (in single quotes)

    ---------------------------------------------------
    -- COMMENTS
    ---------------------------------------------------
    ["@comment"]                              = colors.grayItalic, -- Comments: // line comments and /* block comments */

    ---------------------------------------------------
    -- ERROR HANDLING
    ---------------------------------------------------
    ["@error"]                                = colors
        .redBoldUnderlined -- Error nodes: for invalid syntax or parsing errors
  }
end

return M
