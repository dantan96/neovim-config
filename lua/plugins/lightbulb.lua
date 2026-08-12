-- lua/plugins/lightbulb.lua — a sign when a code action is available.
--
-- lean.nvim's own README recommends this plugin by name (README.md:108), and
-- the VS Code parity audit puts it at #49: `gra` invokes code actions, and
-- nothing signals that one exists. That matters more in Lean than in most
-- languages, because code actions are the ONLY delivery mechanism for
--
--   * `#guard_msgs` repair — accept the message the test actually produced,
--   * unknown-identifier import suggestions,
--   * the Batteries instance / match / induction skeletons,
--
-- (vscode-lean4 manual.md:421-430). You would never think to press `gra` on a
-- line you did not already know was actionable, so without the bulb the whole
-- feature is invisible rather than merely undiscoverable.
--
-- QUIET BY CONSTRUCTION. Every announcement channel this plugin offers is off
-- except the sign column, which Lean files already keep open for lean.nvim's
-- progress bars and multi-line diagnostic guides — so the bulb costs no
-- horizontal space and never reflows text. No float: a popup that appears
-- while you are reading a goal state is the worst possible version of this.
-- No virtual text: it would land exactly where lean.nvim puts its ⚒
-- unsolved-goals marker. No number or line highlight, no status text.
--
-- LEAN ONLY, WHICH TAKES BOTH HALVES. `ft = "lean"` keeps the plugin unloaded
-- until the first Lean file; but its autocmd is created once at setup and
-- would then follow you into every other buffer for the rest of the session,
-- so the pattern is pinned to *.lean too. `ft` alone leaks; the pattern alone
-- would mean loading the plugin at startup.
return {
  {
    "kosayoda/nvim-lightbulb",
    ft = "lean",
    opts = {
      sign = { enabled = true, text = "💡", hl = "LightBulbSign" },
      virtual_text = { enabled = false },
      float = { enabled = false },
      status_text = { enabled = false },
      number = { enabled = false },
      line = { enabled = false },
      autocmd = {
        enabled = true,
        -- CursorHold only. CursorHoldI, which is in the plugin's default set,
        -- would pop the bulb in and out while typing a tactic block.
        events = { "CursorHold" },
        pattern = { "*.lean" },
        -- NEGATIVE MEANS "DO NOT TOUCH 'updatetime'", and it must stay that
        -- way. The plugin's default is to set it to 200 at setup time, which
        -- is a GLOBAL option written the moment a Lean file is opened —
        -- exactly the leak tests/test_lean.lua's "opening a Lean buffer leaks
        -- exactly lean.nvim's breakat" case exists to catch. The value this
        -- config wants is already set at startup by
        -- lua/config/lean/document_highlight.lua, before any snapshot.
        updatetime = -1,
      },
    },
  },
}
