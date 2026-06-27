-- Seamless Ctrl-h/j/k/l navigation between Neovim splits AND WezTerm panes.
-- This is the Neovim half; the WezTerm half is in wezterm.lua (an is_nvim-aware
-- keybinding that passes Ctrl-h/j/k/l through to Neovim, and moves WezTerm panes
-- otherwise). smart-splits detects WezTerm via $WEZTERM_PANE and, at a split
-- edge, hands off to the neighbouring WezTerm pane via `wezterm cli` — so the
-- same four keys move the cursor uniformly across the whole window.
return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = { at_edge = "wrap" },
    keys = {
      { "<c-h>", function() require("smart-splits").move_cursor_left() end, desc = "Go to left split/pane" },
      { "<c-j>", function() require("smart-splits").move_cursor_down() end, desc = "Go to lower split/pane" },
      { "<c-k>", function() require("smart-splits").move_cursor_up() end, desc = "Go to upper split/pane" },
      { "<c-l>", function() require("smart-splits").move_cursor_right() end, desc = "Go to right split/pane" },
    },
  },
}
