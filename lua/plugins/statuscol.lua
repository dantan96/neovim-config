-- lua/plugins/statuscol.lua
--
-- Programmable gutter via statuscol.nvim, configured to show VISUAL-relative
-- line numbers when `:set wrap` is on.
--
-- Native `relativenumber` counts buffer lines, so on a wrapped line the gutter
-- leaves continuation rows blank and any count (e.g. 3) skips whole wrapped
-- lines. Here the number segment is a custom function that, for every *screen
-- row*, computes its distance from the cursor's screen row (using
-- `nvim_win_text_height`, which accounts for wrapping) and prints that. Pair it
-- with the gj/gk motion maps in init.lua and `3<j>` lands on the row labelled 3.
--
-- When wrap is off, every buffer line is exactly one screen row, virtnum is
-- always 0, and the height calls return plain line counts -- so output is
-- identical to the current hybrid (current line absolute, others relative)
-- setup. No regression in unwrapped buffers.

return {
  "luukvbaal/statuscol.nvim",
  lazy = false,
  init = function()
    -- The foldfunc segment below renders nothing while 'foldcolumn' is "0";
    -- reserve one cell so the clickable fold column actually shows.
    vim.opt.foldcolumn = "1"
  end,
  config = function()
    local builtin = require("statuscol.builtin")

    -- Rows spanned by buffer lines a1..b1 (1-based, inclusive). 0 if range empty.
    -- Accounts for wrapping, folds and virtual lines in window `win`.
    local function th(win, a1, b1)
      if b1 < a1 then
        return 0
      end
      return vim.api.nvim_win_text_height(win, { start_row = a1 - 1, end_row = b1 - 1 }).all
    end

    -- Cache the cursor's (line, wrap-segment) per redraw so we resolve virtcol
    -- once per tick instead of once per rendered row.
    local cursor_cache = {}

    local function cursor_pos(win, tick)
      local c = cursor_cache[win]
      if c and c.tick == tick then
        return c.lnum, c.virt
      end
      local pos = vim.api.nvim_win_get_cursor(win) -- {lnum(1-based), col(0-based byte)}
      local clnum = pos[1]
      -- virtual column of the cursor (1-based), then how many screen rows of the
      -- cursor's line sit ABOVE the cursor's own row = its wrap-segment index.
      -- virtcol is 1-based == count of vcols up to & incl. the cursor; end_vcol
      -- is an exclusive upper bound, so pass it directly. -1 -> segments above.
      local cvc = vim.fn.virtcol({ clnum, pos[2] + 1 }, false, win)
      local cvirt = vim.api.nvim_win_text_height(win, {
        start_row = clnum - 1,
        end_row = clnum - 1,
        end_vcol = cvc,
      }).all - 1
      cursor_cache[win] = { tick = tick, lnum = clnum, virt = cvirt }
      return clnum, cvirt
    end

    -- The custom number segment: one call per screen row.
    local function vnum(args)
      local ok, out = pcall(function()
        local win = args.win
        -- Virtual-text rows (diagnostics virt_lines etc.): no number.
        if args.virtnum < 0 then
          return "%=  "
        end
        -- relativenumber off (e.g. fsharp ftplugin): plain absolute on real
        -- rows, blank on wrapped rows -- matches native `number`-only behaviour.
        if not args.rnu then
          if not args.nu then
            return ""
          end
          local hl = (args.relnum == 0) and "%#CursorLineNr#" or "%#LineNr#"
          return hl .. "%=" .. (args.virtnum == 0 and args.lnum or "") .. " "
        end

        local clnum, cvirt = cursor_pos(win, args.tick)
        local tl, tv = args.lnum, args.virtnum

        -- Signed screen-row distance from cursor row to this row.
        local d = (tl >= clnum and th(win, clnum, tl - 1) or -th(win, tl, clnum - 1))
          + tv
          - cvirt

        local hl = (d == 0) and "%#CursorLineNr#" or "%#LineNr#"
        -- Hybrid: cursor's own row shows absolute line number, others relative.
        local n = (d == 0) and args.lnum or math.abs(d)
        return hl .. "%=" .. n .. " "
      end)
      -- Fallback to native semantics if anything above throws.
      if ok then
        return out
      end
      return "%=" .. (args.relnum == 0 and args.lnum or args.relnum) .. " "
    end

    require("statuscol").setup({
      relculright = true,
      segments = {
        -- Fold column (click to toggle folds).
        { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
        -- Sign column (git, diagnostics, ...). `auto = true` hides it when empty.
        { sign = { namespace = { ".*" }, maxwidth = 2, auto = true, wrap = true }, click = "v:lua.ScSa" },
        -- Our visual-relative number column.
        -- `condition` pairs positionally with `text`; one text entry -> one condition.
        { text = { vnum }, condition = { true }, click = "v:lua.ScLa" },
      },
    })
  end,
}
