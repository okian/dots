-- Colorscheme follows `dots theme` (reads ~/.config/dots/theme). All theme
-- plugins are installed; the active slug maps to its colorscheme. New nvim
-- instances pick up the current theme; in a running nvim, `:colorscheme <name>`.
local map = {
  ["catppuccin-mocha"] = "catppuccin-mocha",
  ["nord"] = "nord",
  ["tokyo-night"] = "tokyonight-night",
  ["gruvbox-dark"] = "gruvbox",
}

local function active_slug()
  local f = io.open((os.getenv("HOME") or "") .. "/.config/dots/theme", "r")
  if not f then
    return "catppuccin-mocha"
  end
  local slug = f:read("*l")
  f:close()
  return map[slug or ""] and slug or "catppuccin-mocha"
end

local slug = active_slug()
-- Only the active theme loads eagerly at startup; the other three are lazy and
-- load on demand if ever invoked with `:colorscheme`.
local function spec(theme_slug, repo, name)
  local active = theme_slug == slug
  return { repo, name = name, lazy = not active, priority = active and 1000 or nil }
end

return {
  spec("catppuccin-mocha", "catppuccin/nvim", "catppuccin"),
  spec("nord", "shaunsingh/nord.nvim"),
  spec("tokyo-night", "folke/tokyonight.nvim"),
  spec("gruvbox-dark", "ellisonleao/gruvbox.nvim"),
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = map[slug],
    },
  },
}
