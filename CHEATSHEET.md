# Neovim Keymaps Cheat Sheet

Leader key: `\` (backslash)

## General

| Keys | Mode | Action |
|------|------|--------|
| `<Space><Space>x` | n | Source current file |
| `<Space>x` | n | Execute current line as Lua |
| `<Space>x` | v | Execute visual selection as Lua |
| `<Esc><Esc>` | n, v | Clear search highlights |
| `<leader>ns` | n, v | Clear search highlights (alt) |
| `<C-d>` | n, v | Page down + center cursor |
| `<C-u>` | n, v | Page up + center cursor |

## Clipboard & Registers

| Keys | Mode | Action |
|------|------|--------|
| `<leader>y` | n, v | Yank to system clipboard |
| `<leader>p` | n, v | Paste from system clipboard |
| `<leader>d` | n, v | Delete to black hole register |

## File Navigation & Management

| Keys | Mode | Action |
|------|------|--------|
| `<leader>-` | n | Open Oil file manager |
| `<leader>vim` | n | Open Oil in nvim config dir |
| `<leader>n` | n | New empty buffer |
| `<leader>bn` | n | Next buffer |
| `<leader>bp` | n | Previous buffer |
| `<leader>bd` | n | Delete buffer |
| `<leader>tt` | n | Copy window to new tab |

## Telescope (Fuzzy Finder)

| Keys | Mode | Action |
|------|------|--------|
| `<Space>ff` | n | Find files |
| `<Space>fh` | n | Help tags |
| `<leader>fb` | n | Buffers |
| `<leader>fg` | n | Live multi-grep |
| `<leader>fG` | n | Live multi-grep (nvim config) |
| `<Space>en` | n | Find files in nvim config |
| `<Space>ep` | n | Find files in lazy plugin dir |

## Harpoon (Quick File Marks)

| Keys | Mode | Action |
|------|------|--------|
| `<leader>ha` | n | Add file to harpoon |
| `<leader>hh` | n | Toggle harpoon menu |
| `<leader>1`..`5` | n | Jump to harpoon file 1-5 |

## LSP (Built-in Neovim Defaults)

| Keys | Mode | Action |
|------|------|--------|
| `grn` | n | Rename symbol |
| `gra` | n | Code action |
| `grr` | n | References |
| `gri` | n | Implementations |
| `gO` | n | Document symbols |
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `K` | n | Hover documentation |
| `<C-s>` | i | Signature help |
| `<leader>lx` | n | Toggle diagnostics (buffer) |

## Formatting

| Keys | Mode | Action |
|------|------|--------|
| `<leader>F` | n, v | Format buffer (Conform + LSP fallback) |

## Multi-Cursor

| Keys | Mode | Action |
|------|------|--------|
| `<Up>` | n, x | Add cursor above |
| `<Down>` | n, x | Add cursor below |
| `<leader><Up>` | n, x | Skip cursor above |
| `<leader><Down>` | n, x | Skip cursor below |
| `<leader>n` | n, x | Match word/selection, add cursor next |
| `<leader>s` | n, x | Match word/selection, skip next |
| `<leader>N` | n, x | Match previous |
| `<leader>S` | n, x | Skip previous match |
| `<leader>A` | n, x | Match all in document |
| `mw` | n, x | Create cursors for word in motion range |
| `mW` | n | Custom pattern match in range |
| `<Left>` | n, x | Rotate to next cursor |
| `<Right>` | n, x | Rotate to previous cursor |
| `<leader>X` | n, x | Delete main cursor |
| `<C-q>` | n, x | Toggle cursor |
| `<leader><C-q>` | n, x | Duplicate cursors |
| `<Esc>` | n | Clear cursors or disable |
| `<leader>gv` | n | Restore cleared cursors |
| `<leader>a` | n | Align cursor columns |
| `S` | x | Split visual by regex |
| `I` | x | Insert at each visual line |
| `A` | x | Append at each visual line |
| `M` | x | Match cursors in visual |
| `<leader>t` | x | Rotate visual contents forward |
| `<leader>T` | x | Rotate visual contents backward |
| `<C-i>` | n, x | Jump forward (jumplist) |
| `<C-o>` | n, x | Jump backward (jumplist) |
| `<C-LeftMouse>` | n | Add/remove cursor with click |

## Tmux Navigation

| Keys | Mode | Action |
|------|------|--------|
| `<C-w>h` | n | Navigate left (Vim/Tmux) |
| `<C-w>j` | n | Navigate down (Vim/Tmux) |
| `<C-w>k` | n | Navigate up (Vim/Tmux) |
| `<C-w>l` | n | Navigate right (Vim/Tmux) |
| `<C-w>\` | n | Navigate to previous pane |

## Terminal & Running Code

| Keys | Mode | Action |
|------|------|--------|
| `<leader>T` | n | Open terminal (vertical split) |
| `<leader>r` | n | Run current file in terminal |

## Sessions (Obsession)

| Keys | Mode | Action |
|------|------|--------|
| `<leader>os` | n | Start/resume session |
| `<leader>oS` | n | Stop & delete session |

## Toggles

| Keys | Mode | Action |
|------|------|--------|
| `<leader>ts` | n | Toggle statusline (global) |
| `<leader>tS` | n | Toggle statusline (buffer) |
| `<leader>tv` | n | Toggle Markview (markdown) |
| `<leader>tw` | n | Toggle live hard-wrap (markdown, buffer; prettier wraps on save either way) |
| `<leader>ct` | n | Toggle Colorizer |

## F# (ftplugin)

| Keys | Mode | Action |
|------|------|--------|
| `<M-CR>` | n | Send line to F# Interactive |
| `<M-CR>` | x | Send selection to F# Interactive |
| `<M-@>` | n | Toggle F# Interactive REPL |

## Misc

| Keys | Mode | Action |
|------|------|--------|
| `<leader>#` | n | Insert shebang line |
| `<leader>hc` | n | Capture colour report |

## Neovide Only

| Keys | Mode | Action |
|------|------|--------|
| `<D-=>` | n, v, i | Increase font size |
| `<D-->` | n, v, i | Decrease font size |
| `<D-0>` | n, v, i | Reset font size |
