# config.nu — managed by chezmoi.

# Theme registry + the `dots theme` switcher; defines the active palette below.
source ~/.config/dots/themes.nu

# Active theme (set by `dots theme`; falls back to a built-in default), so the
# nushell table colors, television, bat and starship all follow the chosen theme.
let theme = (_theme_active)
let pal = $theme.palette

$env.config = {
  show_banner: false
  edit_mode: vi
  cursor_shape: { vi_insert: line, vi_normal: block }
  completions: { case_sensitive: false, quick: true, partial: true, algorithm: "fuzzy" }
  history: { max_size: 100_000, file_format: "sqlite" }

  # Table/value colors, derived from the active theme palette.
  color_config: (color_config_from_palette $pal)

  # Completion menu, themed to match. (History search is television's Ctrl-R.)
  menus: [
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "│ "
      type: { layout: columnar columns: 4 col_padding: 2 }
      style: {
        text: $pal.fg
        selected_text: { fg: $pal.bg bg: $pal.accent }
        description_text: $pal.subtle
      }
    }
  ]
  keybindings: [
    { name: completion_menu modifier: none keycode: tab mode: [vi_insert vi_normal]
      event: { until: [ { send: menu name: completion_menu } { send: menunext } ] } }
    # Gray history autosuggestion (shown automatically, colored `hints` in the
    # palette): → accepts the whole thing (reedline default); Ctrl-Y here too;
    # Ctrl-→ accepts just the next word (fish-style partial accept).
    { name: accept_suggestion modifier: control keycode: char_y mode: [vi_insert]
      event: { send: historyhintcomplete } }
    { name: accept_suggestion_word modifier: control keycode: right mode: [vi_insert vi_normal]
      event: { send: historyhintwordcomplete } }
  ]

  hooks: {
    # direnv: load per-project env on each prompt (no-op if direnv absent).
    pre_prompt: [{ ||
      try {
        if (which direnv | is-not-empty) {
          direnv export json | from json | default {} | load-env
        }
      }
    }]
  }
}

# Theme-driven environment: bat theme and the active starship config (a
# palette-swapped copy of starship.toml written by `dots theme`). Television's
# colours follow the theme via a generated theme file, not an env var.
$env.BAT_THEME = $theme.bat
let _ss_cfg = ($nu.home-dir | path join '.config' 'dots' 'starship.toml')
if ($_ss_cfg | path exists) { $env.STARSHIP_CONFIG = $_ss_cfg }

# Aliases
alias ll = ls -la
alias la = ls -a
alias g = git
alias lg = lazygit
alias v = nvim
alias vim = nvim
alias cat = bat
alias top = btop
# Container muscle-memory: docker -> podman.
alias docker = podman
alias dc = podman-compose
alias docker-compose = podman-compose
if (which eza | is-not-empty) {
  alias ls = eza --icons --group-directories-first
  alias lt = eza --tree --level=2 --icons
}

# Fuzzy-find a file (television's `files` channel: bat preview built in) and
# open it in the editor.
def ff [] {
  let file = (^tv files | str trim)
  if ($file | is-not-empty) { ^$env.EDITOR $file }
}

# Fuzzy-find a directory and cd into it (fd feeds television via stdin; tree
# preview from the `dirs` channel definition shipped in config).
def --env fcd [] {
  let dir = (^fd --type d --hidden --follow --exclude .git
    | ^tv --preview-command 'eza --tree --level=2 --color=always {}' | str trim)
  if ($dir | is-not-empty) { cd $dir }
}

# Fuzzy-search code symbols (classes/funcs/vars) in the current project and jump
# to one (television's `symbols` channel: universal-ctags index, bat preview
# scrolled to the line, Enter opens it in the editor). Terminal counterpart to
# Neovim's LSP symbol search.
def fsym [] { ^tv symbols }

# Pick a git project under ~/projects and cd into it (television's `projects`
# channel; Ctrl-S inside jumps to that repo's symbols, Ctrl-E edits).
def --env proj [] {
  let dir = (^tv projects | str trim)
  if ($dir | is-not-empty) { cd $dir }
}

# `y` opens yazi and cd's to wherever you quit it. Hardened over the official
# wrapper: `try` around yazi so the temp file is always cleaned up, and the
# path is trimmed before the comparison.
def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXX")
  try { ^yazi ...$args --cwd-file $tmp }
  let cwd = (open $tmp | str trim)
  rm -fp $tmp
  if $cwd != "" and $cwd != $env.PWD { cd $cwd }
}

# Make a directory (and parents) then cd into it.
def --env mkcd [dir: string] {
  mkdir $dir
  cd $dir
}

# Extract almost any archive by extension — no need to remember the flags.
def extract [file: path] {
  if not ($file | path exists) {
    error make { msg: $"no such file: ($file)" }
    return
  }
  let name = ($file | str downcase)
  if ($name | str ends-with ".tar.gz") or ($name | str ends-with ".tgz") {
    ^tar xzf $file
  } else if ($name | str ends-with ".tar.bz2") {
    ^tar xjf $file
  } else if ($name | str ends-with ".tar.xz") {
    ^tar xJf $file
  } else if ($name | str ends-with ".tar") {
    ^tar xf $file
  } else if ($name | str ends-with ".gz") {
    ^gunzip $file
  } else if ($name | str ends-with ".zip") {
    ^unzip $file
  } else if ($name | str ends-with ".7z") or ($name | str ends-with ".rar") {
    ^7z x $file
  } else {
    error make { msg: $"don't know how to extract ($file)" }
  }
}

# Listening TCP ports with the owning process (macOS + Linux via lsof).
def ports [] {
  ^lsof -nP -iTCP -sTCP:LISTEN
  | lines | skip 1
  | parse --regex '^(?<process>\S+)\s+(?<pid>\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(?<address>.+?)\s+\(LISTEN\)'
  | uniq-by address
  | sort-by address
}

# Fuzzy-pick a running process and kill it (television reads the list on stdin).
def killp [] {
  let pid = (ps | each { |p| $"($p.pid)\t($p.name)" }
    | str join (char nl)
    | ^tv | split row "\t" | first | str trim)
  if ($pid | is-not-empty) { kill $pid }
}

# git add-commit-push in one shot: `gcap "message"`.
def gcap [message: string] {
  git add -A
  git commit -m $message
  git push
}

# starship / zoxide / carapace / television (tv) are auto-sourced from the vendor
# autoload dir populated by env.nu — no manual `source` needed here. tv binds
# Ctrl-T (smart autocomplete) and Ctrl-R (history).

# `dots` commands (update, secrets, hooks, tips, cheatsheet).
source ~/.config/nushell/dots.nu

# Random usage tip on interactive startup only (opt out with $env.DOTS_NO_TIPS).
# Guarded by is-interactive so `nu -c ...` scripts stay clean.
if $nu.is-interactive and ('DOTS_NO_TIPS' not-in $env) { dots tip }
