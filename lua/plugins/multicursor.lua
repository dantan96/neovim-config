return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  event = "VeryLazy",
  config = function()
    local mc = require("multicursor-nvim")

    mc.setup()

    local set = vim.keymap.set

    -- Add or skip cursor above/below the main cursor.
    set({ "n", "x" }, "<up>",
      function() mc.lineAddCursor(-1) end, { desc = "MC add cursor above" })
    set({ "n", "x" }, "<down>",
      function() mc.lineAddCursor(1) end, { desc = "MC add cursor below" })
    set({ "n", "x" }, "<leader><up>",
      function() mc.lineSkipCursor(-1) end, { desc = "MC skip cursor above" })
    set({ "n", "x" }, "<leader><down>",
      function() mc.lineSkipCursor(1) end, { desc = "MC skip cursor below" })

    -- Add or skip adding a new cursor by matching word/selection
    set({ "n", "x" }, "<leader>n",
      function() mc.matchAddCursor(1) end, { desc = "MC match next" })
    set({ "n", "x" }, "<leader>s",
      function() mc.matchSkipCursor(1) end, { desc = "MC skip next" })
    set({ "n", "x" }, "<leader>N",
      function() mc.matchAddCursor(-1) end, { desc = "MC match prev" })
    set({ "n", "x" }, "<leader>S",
      function() mc.matchSkipCursor(-1) end, { desc = "MC skip prev" })

    -- In normal/visual mode, press `mwap` will create a cursor in every match of
    -- the word captured by `iw` (or visually selected range) inside the bigger
    -- range specified by `ap`. Useful to replace a word inside a function, e.g. mwif.
    set({ "n", "x" }, "mw", function()
      mc.operator({ motion = "iw", visual = true })
    end, { desc = "MC match word in range" })

    -- Press `mWi"ap` will create a cursor in every match of string captured by `i"` inside range `ap`.
    set("n", "mW", mc.operator, { desc = "MC match pattern in range" })

    -- Add all matches in the document
    set({ "n", "x" }, "<leader>A", mc.matchAllAddCursors, { desc = "MC match all" })

    -- Rotate the main cursor.
    set({ "n", "x" }, "<left>", mc.nextCursor, { desc = "MC next cursor" })
    set({ "n", "x" }, "<right>", mc.prevCursor, { desc = "MC prev cursor" })

    -- Delete the main cursor.
    set({ "n", "x" }, "<leader>x", mc.deleteCursor, { desc = "MC delete cursor" })

    -- Add and remove cursors with control + left click.
    set("n", "<c-leftmouse>", mc.handleMouse, { desc = "MC add/remove cursor (click)" })
    set("n", "<c-leftdrag>", mc.handleMouseDrag, { desc = "MC drag select" })
    set("n", "<c-leftrelease>", mc.handleMouseRelease, { desc = "MC mouse release" })

    -- Easy way to add and remove cursors using the main cursor.
    set({ "n", "x" }, "<c-q>", mc.toggleCursor, { desc = "MC toggle cursor" })

    -- Clone every cursor and disable the originals.
    set({ "n", "x" }, "<leader><c-q>", mc.duplicateCursors, { desc = "MC duplicate cursors" })

    set("n", "<esc>", function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      elseif mc.hasCursors() then
        mc.clearCursors()
      else
        -- Default <esc> handler.
      end
    end)

    -- bring back cursors if you accidentally clear them
    set("n", "<leader>gv", mc.restoreCursors, { desc = "MC restore cursors" })

    -- Align cursor columns.
    set("n", "<leader>a", mc.alignCursors, { desc = "MC align columns" })

    -- Split visual selections by regex.
    set("x", "S", mc.splitCursors, { desc = "MC split by regex" })

    -- Append/insert for each line of visual selections.
    set("x", "I", mc.insertVisual, { desc = "MC insert visual" })
    set("x", "A", mc.appendVisual, { desc = "MC append visual" })

    -- match new cursors within visual selections by regex.
    set("x", "M", mc.matchCursors, { desc = "MC match in visual" })

    -- Rotate visual selection contents.
    set("x", "<leader>t",
      function() mc.transposeCursors(1) end, { desc = "MC transpose forward" })
    set("x", "<leader>T",
      function() mc.transposeCursors(-1) end, { desc = "MC transpose backward" })

    -- Jumplist support
    set({ "x", "n" }, "<c-i>", mc.jumpForward, { desc = "MC jump forward" })
    set({ "x", "n" }, "<c-o>", mc.jumpBackward, { desc = "MC jump backward" })

    -- Customize how cursors look.
    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { link = "Cursor" })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorMatchPreview", { link = "Search" })
    hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
    hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
  end
}
