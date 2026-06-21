# `essentials` command — one-shot update of configs + every toolchain.
# Usage:  essentials update

def "essentials update" [] {
  print "==> chezmoi update (pull configs + apply)"
  try { ^chezmoi update }

  print "==> brew upgrade"
  try { ^brew upgrade; ^brew cleanup }

  print "==> rustup update"
  try { ^rustup update }

  print "==> swiftly update"
  try { ^swiftly update --assume-yes }

  print "==> uv self update + python"
  try { ^uv self update; ^uv python upgrade }

  print "==> neovim plugin sync"
  try { ^nvim --headless "+Lazy! sync" +qa }

  print "==> doom upgrade"
  let doom = ($nu.home-path | path join '.config' 'emacs' 'bin' 'doom')
  if ($doom | path exists) { try { ^$doom upgrade --force } }

  print "==> done. Everything is at latest."
}

# --- Secrets (age encryption) ----------------------------------------------

# One-time: generate the age keypair on a trusted machine.
def "essentials secrets-setup" [] {
  let dir = ($nu.home-path | path join '.config' 'chezmoi')
  mkdir $dir
  let key = ($dir | path join 'key.txt')
  if ($key | path exists) {
    print $"Key already exists at ($key). Your PUBLIC key:"
    ^age-keygen -y $key
    return
  }
  ^age-keygen -o $key
  ^chmod 600 $key
  print ""
  print "==> Done. Your PUBLIC key (paste into the repo as the age recipient):"
  let pub = (^age-keygen -y $key | str trim)
  print $pub
  print ""
  print "Next:"
  print "  1. Put this PUBLIC key in home/.chezmoi.toml.tmpl  ->  recipient = \"<above>\""
  print "  2. Commit & push the repo."
  print "  3. Run `chezmoi init` to regenerate local config with the recipient."
  print $"  4. Back up ($key) somewhere safe — it is the ONLY way to decrypt."
}

# Encrypt a file and add it to the repo (ciphertext is safe to commit/push).
def "essentials secret-add" [path: string] {
  ^chezmoi add --encrypt $path
  print $"==> Encrypted and staged ($path)."
  print "Commit & push:  chezmoi git -- add . ; chezmoi git -- commit -m secret ; chezmoi git -- push"
}

# --- Global git hooks ------------------------------------------------------

# Show hook status (where they live, enabled?, available tools).
def "essentials hooks status" [] {
  let path = (^git config --global --get core.hooksPath | str trim)
  print $"hooksPath: ($path)"
  let disabled = (^git config --global --get hooks.disable | str trim)
  print $"enabled:   (if $disabled == 'true' { 'no (hooks.disable=true)' } else { 'yes' })"
  print "tools:"
  for t in [gitleaks golangci-lint swiftlint swiftformat ruff ktlint shellcheck git-lfs] {
    print $"  (if (which $t | is-not-empty) { '✓' } else { '·' }) ($t)"
  }
}

# Turn all hooks off / on globally.
def "essentials hooks disable" [] { ^git config --global hooks.disable true;  print "global hooks disabled" }
def "essentials hooks enable"  [] { ^git config --global --unset hooks.disable; print "global hooks enabled" }

# Run the pre-commit hook now against staged changes (dry test).
def "essentials hooks test" [] {
  let h = (^git config --global --get core.hooksPath | str trim | path join 'pre-commit')
  if ($h | path exists) { ^$h } else { print "no pre-commit hook found" }
}

# Bare `essentials` prints help.
def "essentials" [] {
  print "essentials — manage this machine's config, toolchains, secrets & hooks"
  print "  essentials update            upgrade configs + all toolchains to latest"
  print "  essentials secrets-setup     generate the age key (run once, trusted machine)"
  print "  essentials secret-add <p>    encrypt a file & add it to the repo"
  print "  essentials hooks status      show global git-hooks state"
  print "  essentials hooks enable|disable|test"
  print ""
  print "  chezmoi edit <file>   edit a config"
  print "  chezmoi diff          preview pending changes"
  print "  chezmoi apply         apply local edits"
}
