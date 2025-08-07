; Increase priority for delimiter punctuation
([
  ","
  ";"
  ":"
  "."
] @punctuation.delimiter
  (#set! "priority" 150))
