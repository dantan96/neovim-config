; Give the prose its own base colour.
;
; WHY THIS EXISTS. Markdown's grammar captures only what has STRUCTURE —
; headings, code spans, emphasis, links. A plain paragraph gets no capture at
; all, so its colour fell through to whatever was underneath: `leanBlockComment`,
; i.e. comment grey, italic. Measured on a rendered buffer, the words "Finish
; the proof" reported `treesitter=[spell(markdown)] syntax=[leanBlockComment]` —
; nothing but a spell region. That is why the page read as code interspersed
; with comments rather than as a page: the prose was literally wearing the
; comment colour.
;
; Capturing the whole doc-comment node gives the body text a colour of its own,
; and the injected markdown captures still land on top of it, so headings, bold
; and inline code keep theirs.
;
; SAFETY. These are the only two captures this grammar has, and both are
; comment nodes. Nothing here can reach code — which is the property that lets
; the tree-sitter highlighter run at all in a Lean buffer without disturbing the
; palette. Do not add a capture for `_code` or `string`.

((module_doc_comment) @lean.prose)
((doc_comment) @lean.prose)
