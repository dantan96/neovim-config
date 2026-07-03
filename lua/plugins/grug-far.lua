-- lua/plugins/grug-far.lua
-- Project-wide search & replace UI (ripgrep-backed).
-- <leader>fr joins the existing telescope <leader>f* family, so no new
-- single-char leader key is stalled.
return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>fr",
        function() require("grug-far").open() end,
        desc = "Find & replace (GrugFar)",
      },
      {
        "<leader>fr",
        function() require("grug-far").with_visual_selection() end,
        mode = "x",
        desc = "Find & replace selection (GrugFar)",
      },
    },
    opts = {},
  },
}
