-- Seamless navigation between Neovim splits and tmux panes with Ctrl-h/j/k/l.
-- This is the Neovim half; the tmux half is `christoomey/vim-tmux-navigator`
-- declared in ~/.tmux.conf. Both must be present for the boundary to be
-- transparent — Ctrl-h at the edge of a split steps into the tmux pane and back.
return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window/pane" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window/pane" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window/pane" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window/pane" },
      { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Go to previous window/pane" },
    },
  },
}
