# config.nu — managed by chezmoi.

$env.config = {
  show_banner: false
  edit_mode: vi
  cursor_shape: { vi_insert: line, vi_normal: block }
  completions: { case_sensitive: false, quick: true, partial: true, algorithm: "fuzzy" }
  history: { max_size: 100_000, file_format: "sqlite" }
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
# Container muscle-memory: docker -> podman.
alias docker = podman
alias dc = podman-compose
alias docker-compose = podman-compose
if (which eza | is-not-empty) {
  alias ls = eza --icons --group-directories-first
  alias lt = eza --tree --level=2 --icons
}

# starship / zoxide / carapace / atuin are auto-sourced from the vendor autoload
# dir populated by env.nu — no manual `source` needed here.

# `essentials update` — pull configs + upgrade every toolchain to latest.
source ~/.config/nushell/essentials.nu
