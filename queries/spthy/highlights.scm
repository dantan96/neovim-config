(single_comment) @spthycomment
(multi_comment) @spthycomment

((pub_name) @spthypublic.constant
(#has-parent? @spthypublic.constant tuple_term))

((pub_name) @spthypublic.constant
(#not-has-parent? @spthypublic.constant tuple_term))

((ident) @spthyvariable.message
 (#has-parent? @spthyvariable.message msg_var_or_nullary_fun))

(fresh_var) @spthyvariable.fresh
(pub_var) @spthyvariable.public
(temporal_var) @spthyvariable.temporal

(["<" "," ">" ] @spthytuple
 (#has-parent? @spthytuple tuple_term))


;; Keywords - using direct token identification
[
  "theory"
  "begin"
  "end"
  "equations"
] @spthykeyword


[
 "builtins"
 "functions"
 "predicates"
 "options"
] @spthykeyword.module

[
 "all-traces"
 "exists-trace"
] @spthykeyword.trace_quantifier


[
 "All"
 "Ex"
 "∀"
 "∃"
] @spthykeyword.quantifier


[
 "rule"
 "lemma"
 "axiom"
 "restriction"
] @spthykeyword.function


[
 "tactic"
 "presort"
 "prio"
 "deprio"
] @spthykeyword.tactic


[
 "sorry"
 "simplify"
 "solve"
 "contradiction"
] @spthykeyword.tactic.value

[
 "macros"
 "let"
 "in"
] @spthykeyword.macro


[
 "#ifdef"
 "#endif"
 "#define"
 "#include"
] @spthypreproc

;;((ident) @spthypreproc.identifier
;; (#has-parent? @spthypreproc 


;; Identifiers - using the ident node type with text predicates for differentiation
;; Theory name
((ident) @spthytype
 (#has-parent? @spthytype theory))

(function_untyped function_identifier: (ident)) @spthyfunction

((ident) @spthyfunction
(#has-parent? @spthyfunction function_untyped))

((ident) @spthyfunction
(#has-parent? @spthyfunction function_typed))

((natural) @spthyfunction.arity
(#has-parent? @spthyfunction.arity function_untyped))

((natural) @spthyfunction.arity
(#has-parent? @spthyfunction.arity function_typed))

;; Rule identifiers - using parent and position checking
((ident) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule simple_rule))

((ident) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule lemma))


((ident) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule diff_lemma))

((ident) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule restriction))

((built_in) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule built_ins))



;; Variable identifiers in terms

;; Function identifiers for built-in facts
((ident) @spthyfact.builtin
 (#has-parent? @spthyfact.builtin linear_fact)
 (#any-of? @spthyfact.builtin "In" "Out" "Fr" "K" "KU" "KD"))

((ident) @spthyfunction
 (#has-parent? @spthyfunction nary_app))

;; Function identifiers for crypto operations
((ident) @spthyfunction.builtin
 (#has-parent? @spthyfunction.builtin nary_app)
 (#any-of? @spthyfunction.builtin 
  "aenc" 
  "adec" 
  "senc" 
  "sdec" 
  "mac" 
  "kdf" 
  "pk" 
  "h" 
  "verify" 
  "sign" 
  "true"
  "revealSign"
  "revealVerify"
  "getMessage"
  "inv"
  "1"
  "zero"
  "⊕"
  "XOR"
  "zero"
  ))


((ident) @spthyfunction.builtin
 (#has-parent? @spthyfunction.builtin function_untyped)
 (#any-of? @spthyfunction.builtin "aenc" "adec" "senc" "sdec" "mac" "kdf" "pk" "h" "verify" "sign" "true" "revealSign" "revealVerify" "getMessage" "inv" "1" "zero" "⊕" "XOR" "zero"))

((ident) @spthyfunction.builtin
 (#has-parent? @spthyfunction.builtin function_typed)
 (#any-of? @spthyfunction.builtin "aenc" "adec" "senc" "sdec" "mac" "kdf" "pk" "h" "verify" "sign" "true" "revealSign" "revealVerify" "getMessage" "inv" "1" "zero" "⊕" "XOR" "zero"))

;; Facts - with different styles
((ident) @spthyfact.action
(#has-parent? @spthyfact.action linear_fact)
(#has-ancestor? @spthyfact.action action_fact))
;; (action_fact (linear_fact)) @spthyfact.action

((ident) @spthyfact.linear
 (#has-parent? @spthyfact.linear linear_fact)
 (#not-has-ancestor? @spthyfact.linear action_fact))


((ident) @spthyfunction.rule
 (#has-parent? @spthyfunction.rule simple_rule))

((ident) @spthyfact.persistent
(#has-parent? @spthyfact.persistent persistent_fact)
(#not-has-ancestor? @spthyfact.persistent linear_fact)
(#not-has-ancestor? @spthyfact.persistent nary_app)
(#not-has-ancestor? @spthyfact.persistent action_fact))


("!" @spthyfact.persistent
 (#has-parent? @spthyfact.persistent premise))

("!" @spthyfact.persistent
 (#has-parent? @spthyfact.persistent conclusion))


;; Rule structure elements
(premise) @spthypremise
(conclusion) @spthyconclusion
(simple_rule) @spthyrule.simple


;; Operators

;; For rules
["--[" "]->"] @spthyoperator.action
["-->"] @spthyoperator.actionless

;; For let blah = blah
["="] @spthyoperator.assignment

;; For lemmas and proofs
["^"] @spthyoperator.exponentiation
["&" "|" "not" ] @spthyoperator.logical
["==>"] @spthyoperator.implies

(["<"] @spthyoperator.lessthan
 (#has-parent? @spthyoperator.lessthan temp_var_order)
 (#not-has-parent? @spthyoperator.lessthan tuple_term))

;; Punctuation

;; Brackets
["[" "]"] @spthypunctuation.bracket.square
["(" ")"] @spthypunctuation.bracket.round

;; Delimiters
([","] @spthypunctuation.delimiter.comma
 (#not-has-ancestor? @spthypunctuation.delimiter.comma tuple_term))

["."] @spthypunctuation.delimiter.period
[";"] @spthypunctuation.delimiter.semicolon
[":"] @spthypunctuation.delimiter.colon

;; Special
["@"] @spthyoperator.at

;(["," ";" ":" "."] @spthypunctuation.delimiter
; (#not-has-ancestor? @spthypunctuation.delimiter tuple_term))
;
;(["," ":" ";"] @spthypunctuation.delimiter_sans_period 
; (#not-has-ancestor? @spthypunctuation.delimiter_sans_period tuple_term))


;; Trace elements
(trace_quantifier) @spthykeyword.quantifier

;; Message components and terms
;; When parent node is exp_term, mul_term, etc.
;((ident) @spthyvariable.message
; (#has-ancestor? @spthyvariable.message mset_term))

;; When ident is inside argument of a linear_fact
;((ident) @spthyvariable.message
; (#has-ancestor? @spthyvariable.message arguments)
; (#has-ancestor? @spthyvariable.message linear_fact))

;; Error nodes for debugging
(ERROR) @spthyerror 
