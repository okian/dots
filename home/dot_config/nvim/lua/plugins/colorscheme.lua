-- Example user override: pick the default colorscheme.
-- Add more files under lua/plugins/ to customize; LazyVim auto-imports them.
return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
