-- WezTerm config — managed by chezmoi.
local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

local is_mac = wezterm.target_triple:find("apple%-darwin") ~= nil

-- ── Appearance ──────────────────────────────────────────────────────────────
config.color_scheme = "Catppuccin Mocha"
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
})
config.font_size = 14.0
config.line_height = 1.05
-- JetBrains Mono ligatures (calt/liga/clig on by default; opt back in explicitly).
config.harfbuzz_features = { "calt=1", "liga=1", "clig=1" }

config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }
config.window_background_opacity = 0.97
-- Background blur is macOS-only; leave Linux/X11 untouched.
if is_mac then
  config.macos_window_background_blur = 30
end
config.scrollback_lines = 10000

-- Dim the pane that doesn't have focus so the eye lands on the active one.
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.65 }

-- Subtle visual bell flash instead of silence (audible bell stays off).
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_duration_ms = 60,
  fade_out_duration_ms = 180,
  target = "CursorColor",
}

-- ── Tab bar ─────────────────────────────────────────────────────────────────
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false

-- Catppuccin Mocha palette, reused by the tab/status formatters below.
local mocha = {
  base = "#1e1e2e", mantle = "#181825", crust = "#11111b",
  text = "#cdd6f4", subtext = "#a6adc8", overlay = "#6c7086",
  surface0 = "#313244",
  mauve = "#cba6f7", green = "#a6e3a1", peach = "#fab387",
  sky = "#89dceb", red = "#f38ba8",
}

config.colors = {
  tab_bar = {
    background = mocha.crust,
    active_tab = { bg_color = mocha.surface0, fg_color = mocha.text },
    inactive_tab = { bg_color = mocha.mantle, fg_color = mocha.subtext },
    inactive_tab_hover = { bg_color = mocha.surface0, fg_color = mocha.text },
    new_tab = { bg_color = mocha.crust, fg_color = mocha.subtext },
    new_tab_hover = { bg_color = mocha.surface0, fg_color = mocha.text },
  },
}

-- Map a foreground process to a Nerd Font glyph for the tab title.
local function process_icon(name)
  local icons = {
    nu = "", bash = "", zsh = "", fish = "",
    nvim = "", vim = "",
    git = "", lazygit = "", k9s = "󱃾", btop = "",
    node = "", python = "", go = "", cargo = "", docker = "", podman = "",
    yazi = "", ssh = "",
  }
  return icons[name] or ""
end

-- Tab title: " <idx> <icon> <process>  <cwd>".
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _conf, _hover, max_width)
  local pane = tab.active_pane
  local proc = (pane.foreground_process_name or ""):match("([^/\\]+)$") or ""
  local cwd = ""
  local uri = pane.current_working_dir
  if uri then
    local path = uri.file_path or tostring(uri)
    cwd = (path:gsub("/$", "")):match("([^/]+)$") or ""
  end
  local title = string.format(" %d %s %s ", tab.tab_index + 1, process_icon(proc), proc)
  if #cwd > 0 then
    title = title .. cwd .. " "
  end
  if #title > max_width then
    title = wezterm.truncate_right(title, max_width - 1) .. "…"
  end
  return title
end)

-- ── Right status line: leader · workspace · battery · clock ──────────────────
wezterm.on("update-right-status", function(window, _pane)
  local cells = {}

  if window:leader_is_active() then
    table.insert(cells, { Background = { Color = mocha.peach } })
    table.insert(cells, { Foreground = { Color = mocha.crust } })
    table.insert(cells, { Text = "  " })
    table.insert(cells, "ResetAttributes")
    table.insert(cells, { Text = " " })
  end

  table.insert(cells, { Foreground = { Color = mocha.green } })
  table.insert(cells, { Text = " " .. window:active_workspace() .. "  " })

  for _, b in ipairs(wezterm.battery_info()) do
    local pct = math.floor(b.state_of_charge * 100 + 0.5)
    local glyph = b.state == "Charging" and "" or ""
    table.insert(cells, { Foreground = { Color = mocha.sky } })
    table.insert(cells, { Text = string.format("%s %d%%  ", glyph, pct) })
  end

  table.insert(cells, { Foreground = { Color = mocha.mauve } })
  table.insert(cells, { Text = " " .. wezterm.strftime("%H:%M") .. " " })

  window:set_right_status(wezterm.format(cells))
end)

-- ── Keybindings ──────────────────────────────────────────────────────────────
-- Leader = Ctrl-Space (no conflict with shell Ctrl-a or tmux).
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  -- Splits.
  { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER",       action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  -- Navigate panes.
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  -- Resize panes.
  { key = "H", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "J", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "K", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "L", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
  -- Pane lifecycle.
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  -- Tabs.
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  -- Modes / pickers.
  { key = "[",     mods = "LEADER",       action = act.ActivateCopyMode },
  { key = "f",     mods = "LEADER",       action = act.QuickSelect },
  { key = "Space", mods = "LEADER",       action = act.ActivateCommandPalette },
  { key = "w",     mods = "LEADER",       action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
  -- Font size.
  { key = "=", mods = "CMD|CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CMD|CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CMD|CTRL", action = act.ResetFontSize },
  -- Fullscreen.
  { key = "Enter", mods = "CMD|CTRL", action = act.ToggleFullScreen },
}

-- Jump straight to a tab with LEADER+<n>.
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i), mods = "LEADER", action = act.ActivateTab(i - 1),
  })
end

-- Match more URL shapes for Ctrl/Cmd-click opening.
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Uses the login shell (nushell, set by provisioning) — no default_prog needed.

return config
