# config.nu — managed by chezmoi.

# Catppuccin Mocha palette — matches WezTerm/FZF/tmux/Neovim.
let mocha = {
  rosewater: "#f5e0dc", flamingo: "#f2cdcd", pink: "#f5c2e7", mauve: "#cba6f7"
  red: "#f38ba8", maroon: "#eba0ac", peach: "#fab387", yellow: "#f9e2af"
  green: "#a6e3a1", teal: "#94e2d5", sky: "#89dceb", sapphire: "#74c7ec"
  blue: "#89b4fa", lavender: "#b4befe", text: "#cdd6f4", subtext1: "#bac2de"
  subtext0: "#a6adc8", overlay1: "#7f849c", surface0: "#313244", base: "#1e1e2e"
}

$env.config = {
  show_banner: false
  edit_mode: vi
  cursor_shape: { vi_insert: line, vi_normal: block }
  completions: { case_sensitive: false, quick: true, partial: true, algorithm: "fuzzy" }
  history: { max_size: 100_000, file_format: "sqlite" }

  # Table/value colors mapped onto the Mocha palette.
  color_config: {
    separator: $mocha.overlay1
    header: { fg: $mocha.subtext0 attr: b }
    row_index: $mocha.overlay1
    empty: $mocha.overlay1
    leading_trailing_space_bg: { attr: n }
    bool: $mocha.sky
    int: $mocha.text
    filesize: $mocha.peach
    duration: $mocha.peach
    date: $mocha.subtext0
    range: $mocha.text
    float: $mocha.text
    string: $mocha.text
    nothing: $mocha.overlay1
    cell-path: $mocha.subtext0
    hints: $mocha.overlay1
    search_result: { fg: $mocha.base bg: $mocha.yellow }
    shape_directory: { fg: $mocha.blue attr: b }
    shape_external: $mocha.teal
    shape_internalcall: { fg: $mocha.sky attr: b }
    shape_flag: { fg: $mocha.mauve attr: b }
    shape_string: $mocha.green
    shape_filepath: $mocha.teal
    shape_globpattern: $mocha.teal
    shape_int: $mocha.peach
    shape_literal: $mocha.blue
    shape_operator: $mocha.sky
    shape_pipe: { fg: $mocha.mauve attr: b }
    shape_garbage: { fg: $mocha.base bg: $mocha.red }
    shape_variable: $mocha.mauve
  }

  # Completion menu, themed to match. (History search is atuin's Ctrl-R.)
  menus: [
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "│ "
      type: { layout: columnar columns: 4 col_padding: 2 }
      style: {
        text: $mocha.text
        selected_text: { fg: $mocha.base bg: $mocha.mauve }
        description_text: $mocha.subtext0
      }
    }
  ]
  keybindings: [
    { name: completion_menu modifier: none keycode: tab mode: [vi_insert vi_normal]
      event: { until: [ { send: menu name: completion_menu } { send: menunext } ] } }
    { name: accept_suggestion modifier: control keycode: char_y mode: [vi_insert]
      event: { send: historyhintcomplete } }
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

# Fuzzy-find a file and open it in the editor.
def ff [] {
  let file = (^fd --type f --hidden --follow --exclude .git
    | ^fzf --preview 'bat --color=always --style=numbers {} 2>/dev/null' | str trim)
  if ($file | is-not-empty) { ^$env.EDITOR $file }
}

# Fuzzy-find a directory and cd into it.
def --env fcd [] {
  let dir = (^fd --type d --hidden --follow --exclude .git
    | ^fzf --preview 'eza --tree --level=2 --color=always {}' | str trim)
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

# Fuzzy-pick a running process and kill it.
def killp [] {
  let pid = (ps | each { |p| $"($p.pid)\t($p.name)" }
    | str join (char nl)
    | ^fzf --with-nth=2.. | split row "\t" | first | str trim)
  if ($pid | is-not-empty) { kill $pid }
}

# git add-commit-push in one shot: `gcap "message"`.
def gcap [message: string] {
  git add -A
  git commit -m $message
  git push
}

# starship / zoxide / carapace / atuin are auto-sourced from the vendor autoload
# dir populated by env.nu — no manual `source` needed here.

# `essentials` commands (update, secrets, hooks, tips, cheatsheet).
source ~/.config/nushell/essentials.nu

# Random usage tip on interactive startup only (opt out with $env.ESSENTIALS_NO_TIPS).
# Guarded by is-interactive so `nu -c ...` scripts stay clean.
if $nu.is-interactive and ('ESSENTIALS_NO_TIPS' not-in $env) { essentials tip }
