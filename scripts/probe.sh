#!/usr/bin/env bash
# probe.sh — empirically inspect how this config actually renders/attaches to a file.
#
# Static reading cannot confirm highlighting or LSP behaviour: it depends on
# query resolution order, extmark priorities and semantic-token timing. Run this
# after any highlight / LSP / treesitter change and paste the JSON into the
# commit or the conversation.
#
#   scripts/probe.sh <file> [line] [col]
#   scripts/probe.sh ~/Projects/FSharp/NinetyNine/src/Lib.fs 12 5
#
# Emits a single JSON object on stdout. Exits non-zero if the probe itself
# failed — note that a plain `nvim --headless -c 'lua error(...)'` exits 0, which
# is why this script ends with an explicit `cquit`.

set -uo pipefail

FILE="${1:-}"
LINE="${2:-1}"
COL="${3:-1}"

if [ -z "$FILE" ]; then
  echo "usage: probe.sh <file> [line] [col]" >&2
  exit 2
fi
if [ ! -r "$FILE" ]; then
  echo "probe.sh: cannot read '$FILE'" >&2
  exit 2
fi

CFG="${HOME}/.config/nvim"
FILE_ABS="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"
OUT="$(mktemp -t nvim-probe)"
trap 'rm -f "$OUT"' EXIT

# --noswapfile/shortmess+=A mirror tests/helpers.lua: a stale swapfile from a
# killed session otherwise sends a headless nvim down the ATTENTION path and
# leaves an empty buffer, which reads as "no highlights" and wastes a cycle.
nvim --headless -u "$CFG/init.lua" \
  --cmd 'set noswapfile shortmess+=A' \
  --cmd "let \$GHOSTTY_NVIM_THEME = ''" \
  -c "lua vim.g.__probe_out = '$OUT'" \
  -c "lua vim.g.__probe_line = $LINE" \
  -c "lua vim.g.__probe_col = $COL" \
  -c "edit $FILE_ABS" \
  -c "luafile $CFG/scripts/probe.lua" \
  >/dev/null 2>&1

status=$?
if [ ! -s "$OUT" ]; then
  echo "probe.sh: probe produced no output (nvim exit $status)" >&2
  exit 1
fi

cat "$OUT"
exit 0
