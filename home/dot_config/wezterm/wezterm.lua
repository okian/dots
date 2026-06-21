-- WezTerm config — managed by chezmoi.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "Catppuccin Mocha"
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
})
config.font_size = 14.0
config.line_height = 1.05

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }
config.scrollback_lines = 10000
config.audible_bell = "Disabled"

-- Uses the login shell (nushell, set by provisioning) — no default_prog needed.

return config
