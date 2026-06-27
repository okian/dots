-- WezTerm config — managed by chezmoi.
local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

local is_mac = wezterm.target_triple:find("apple%-darwin") ~= nil
local home = os.getenv("HOME")

-- ── Theme ────────────────────────────────────────────────────────────────────
-- Colors come from the active theme palette written by `dots theme`
-- (~/.config/dots/palette.json). WezTerm watches that file and hot-reloads, so
-- `dots theme set <name>` retints every open window instantly. Falls back to
-- Catppuccin Mocha until the file exists.
local palette_file = home .. "/.config/dots/palette.json"
local function read_palette()
  local f = io.open(palette_file, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  local ok, parsed = pcall(wezterm.json_parse, data)
  if ok and parsed and parsed.palette then return parsed.palette end
  return nil
end
local p = read_palette() or {
  bg = "#1e1e2e", bg_dark = "#11111b", surface = "#313244", overlay = "#6c7086",
  fg = "#cdd6f4", subtle = "#a6adc8", red = "#f38ba8", green = "#a6e3a1",
  yellow = "#f9e2af", blue = "#89b4fa", magenta = "#cba6f7", cyan = "#94e2d5",
  orange = "#fab387", accent = "#cba6f7",
}
wezterm.add_to_config_reload_watch_list(palette_file)

config.colors = {
  foreground = p.fg, background = p.bg,
  cursor_bg = p.accent, cursor_border = p.accent, cursor_fg = p.bg,
  selection_bg = p.surface, selection_fg = p.fg,
  ansi = { p.bg_dark, p.red, p.green, p.yellow, p.blue, p.magenta, p.cyan, p.subtle },
  brights = { p.overlay, p.red, p.green, p.yellow, p.blue, p.magenta, p.cyan, p.fg },
  tab_bar = {
    background = p.bg_dark,
    active_tab = { bg_color = p.surface, fg_color = p.fg },
    inactive_tab = { bg_color = p.bg_dark, fg_color = p.subtle },
    inactive_tab_hover = { bg_color = p.surface, fg_color = p.fg },
    new_tab = { bg_color = p.bg_dark, fg_color = p.subtle },
    new_tab_hover = { bg_color = p.surface, fg_color = p.fg },
  },
}

-- ── Appearance ──────────────────────────────────────────────────────────────
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
})
config.font_size = 14.0
config.line_height = 1.05

config.window_decorations = "RESIZE"
-- Roomier padding so text breathes away from the window edge.
config.window_padding = { left = 24, right = 24, top = 22, bottom = 20 }
-- Semi-transparent, glassy look. Pair the opacity with a heavy macOS blur so the
-- background reads as frosted glass rather than just see-through.
config.window_background_opacity = 0.85
-- Background blur is macOS-only; leave Linux/X11 untouched.
if is_mac then
  config.macos_window_background_blur = 40
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
  local title = string.format("  %d %s %s ", tab.tab_index + 1, process_icon(proc), proc)
  if #cwd > 0 then
    title = title .. cwd .. " "
  end
  title = title .. " "
  if #title > max_width then
    title = wezterm.truncate_right(title, max_width - 1) .. "…"
  end
  return title
end)

-- ── Right status line: leader · workspace · battery · clock ──────────────────
wezterm.on("update-right-status", function(window, _pane)
  -- Small left spacer so the first tab doesn't sit flush against the edge.
  window:set_left_status(wezterm.format({ { Text = "  " } }))

  local cells = {}

  if window:leader_is_active() then
    table.insert(cells, { Background = { Color = p.orange } })
    table.insert(cells, { Foreground = { Color = p.bg_dark } })
    table.insert(cells, { Text = "  " })
    table.insert(cells, "ResetAttributes")
    table.insert(cells, { Text = " " })
  end

  table.insert(cells, { Foreground = { Color = p.green } })
  table.insert(cells, { Text = " " .. window:active_workspace() .. "  " })

  for _, b in ipairs(wezterm.battery_info()) do
    local pct = math.floor(b.state_of_charge * 100 + 0.5)
    local glyph = b.state == "Charging" and "" or ""
    table.insert(cells, { Foreground = { Color = p.cyan } })
    table.insert(cells, { Text = string.format("%s %d%%  ", glyph, pct) })
  end

  table.insert(cells, { Foreground = { Color = p.accent } })
  table.insert(cells, { Text = " " .. wezterm.strftime("%H:%M") .. "   " })

  window:set_right_status(wezterm.format(cells))
end)

-- ── Pane navigation (unified with Neovim) ────────────────────────────────────
-- Ctrl-h/j/k/l moves between WezTerm panes — but when Neovim is the foreground
-- process the key is passed through so smart-splits.nvim moves the Neovim split
-- (and hands back to WezTerm at the edge). One navigation idiom everywhere.
local function is_nvim(pane)
  return (pane:get_foreground_process_name() or ""):find("nvim") ~= nil
end
local nav_dirs = { h = "Left", j = "Down", k = "Up", l = "Right" }
local function split_nav(key)
  return {
    key = key,
    mods = "CTRL",
    action = wezterm.action_callback(function(win, pane)
      if is_nvim(pane) then
        win:perform_action(act.SendKey({ key = key, mods = "CTRL" }), pane)
      else
        win:perform_action(act.ActivatePaneDirection(nav_dirs[key]), pane)
      end
    end),
  }
end

-- ── Keybindings ──────────────────────────────────────────────────────────────
-- Leader = Ctrl-Space (no conflict with shell Ctrl-a).
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  -- Splits.
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-",  mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  -- Navigate panes (Ctrl-h/j/k/l, shared with Neovim).
  split_nav("h"),
  split_nav("j"),
  split_nav("k"),
  split_nav("l"),
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

-- ── Mouse ─────────────────────────────────────────────────────────────────
-- No title bar (window_decorations = "RESIZE"), so allow dragging the window
-- from anywhere with CMD held. Plain click/drag still selects text. CMD (not
-- CTRL) because macOS captures CTRL+click as a system secondary-click, so a
-- CTRL+Left drag never reaches WezTerm on some Macs.
config.mouse_bindings = {
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = act.StartWindowDrag,
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = act.StartWindowDrag,
  },
}

-- Match more URL shapes for link detection.
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Clicking a link COPIES it to the clipboard instead of opening it in a browser.
-- `open-uri` fires with the link under the cursor right before WezTerm would open
-- it; copying the URI and returning false cancels that default open.
wezterm.on("open-uri", function(window, _pane, uri)
  window:copy_to_clipboard(uri)
  window:toast_notification("WezTerm", "Link copied: " .. uri, nil, 3000)
  return false
end)

-- Uses the login shell (nushell, set by provisioning) — no default_prog needed.

return config
