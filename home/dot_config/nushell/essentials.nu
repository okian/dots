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

  print "==> uv: install latest python (uv itself is updated by brew above)"
  try { ^uv python install }

  print "==> uv tools upgrade (pytest, mypy, …)"
  if (which uv | is-not-empty) { try { ^uv tool upgrade --all } }

  print "==> npm global tools update"
  if (which npm | is-not-empty) { try { ^npm update -g } }

  print "==> neovim plugin sync"
  try { ^nvim --headless "+Lazy! sync" +qa }

  print "==> doom upgrade"
  let doom = ($nu.home-dir | path join '.config' 'emacs' 'bin' 'doom')
  if ($doom | path exists) { try { ^$doom upgrade --force } }

  print "==> done. Everything is at latest."
}

# --- Repo / dotfiles management (one command, no raw chezmoi) ---------------
# Mental model:  edit → diff → apply  (local);  pull ↓ / save ↑  (remote).

def _have_chezmoi [] {
  if (which chezmoi | is-empty) { print "✗ chezmoi is not installed on this machine."; false } else { true }
}

# Preview what applying would change in $HOME.
def "essentials diff" [] {
  if not (_have_chezmoi) { return }
  ^chezmoi diff
}

# Apply your local source edits to $HOME.
def "essentials apply" [] {
  if not (_have_chezmoi) { return }
  ^chezmoi apply
  print "==> applied."
}

# Edit a managed file (edits the source, then applies it). e.g. essentials edit ~/.config/git/config
def "essentials edit" [...file: string] {
  if not (_have_chezmoi) { return }
  if ($file | is-empty) { print "usage: essentials edit <file> [<file> …]"; return }
  ^chezmoi edit --apply ...$file
}

# Show the fully rendered content a target file would have.
def "essentials show" [file: string] {
  if not (_have_chezmoi) { return }
  ^chezmoi cat $file
}

# Start managing an existing file (copy it into the repo). --encrypt for secrets.
def "essentials add" [path: string, --encrypt] {
  if not (_have_chezmoi) { return }
  if $encrypt { ^chezmoi add --encrypt $path } else { ^chezmoi add $path }
  print $"==> now managing ($path)(if $encrypt { ' (encrypted)' } else { '' })."
}

# Stop managing a file (leaves it in $HOME, removes it from the repo).
def "essentials forget" [path: string] {
  if not (_have_chezmoi) { return }
  ^chezmoi forget $path
}

# Pull the latest from the remote and apply (git pull + apply). The downward
# counterpart to `save`. (`essentials update` also upgrades every toolchain.)
def "essentials pull" [] {
  if not (_have_chezmoi) { return }
  ^chezmoi update
  print "==> pulled & applied."
}

# Save ALL local repo changes upward: stage everything, commit, push.
def "essentials save" [message?: string] {
  if not (_have_chezmoi) { return }
  let dirty = (^chezmoi git -- status --porcelain | complete | get stdout | str trim)
  if ($dirty | is-empty) { print "nothing to save — the repo is clean."; return }
  ^chezmoi git -- add -A
  ^chezmoi git -- commit -m ($message | default "update dotfiles")
  ^chezmoi git -- push
  print "==> saved (committed & pushed)."
}

# Overview: repo git status + a summary of pending changes to apply.
def "essentials status" [] {
  if not (_have_chezmoi) { return }
  print "── repo (uncommitted changes) ──"
  ^chezmoi git -- status -sb
  print ""
  print "── pending apply (chezmoi diff) ──"
  let d = (^chezmoi diff | complete | get stdout)
  if ($d | str trim | is-empty) { print "  (none — $HOME matches the repo)" } else { print $d }
}

# Jump into the dotfiles source directory.
def --env "essentials cd" [] {
  if not (_have_chezmoi) { return }
  cd (^chezmoi source-path | str trim)
}

# Recent commit history of the dotfiles repo.
def "essentials log" [n: int = 15] {
  if not (_have_chezmoi) { return }
  ^chezmoi git -- log --oneline -n $n
}

# List every file this repo manages.
def "essentials managed" [] {
  if not (_have_chezmoi) { return }
  ^chezmoi managed
}

# Diagnose the chezmoi/toolchain setup.
def "essentials doctor" [] {
  if not (_have_chezmoi) { return }
  ^chezmoi doctor
}

# --- Secrets (age encryption) ----------------------------------------------

# One-time: generate the age keypair on a trusted machine.
def "essentials secrets-setup" [] {
  let dir = ($nu.home-dir | path join '.config' 'chezmoi')
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

# --- Per-entity git identities (driven by ~/repos) -------------------------
# Each top-level dir under ~/repos is an entity (work, personal, NGO…) with its
# own git identity. See ~/bins/git-identities-sync for the full mechanism.

def _gi_confd [] { $nu.home-dir | path join '.config' 'git' 'conf.d' }
def _gi_file [entity: string] { (_gi_confd) | path join $"($entity).gitconfig" }

# Regenerate the includeIf blocks from the current ~/repos layout.
def "essentials git-identity sync" [] {
  let bin = ($nu.home-dir | path join 'bins' 'git-identities-sync')
  if ($bin | path exists) { ^$bin } else { print "git-identities-sync not installed — run `chezmoi apply`" }
}

# List entities, their resolved identity, and whether a ~/repos dir exists.
def "essentials git-identity list" [] {
  let confd = (_gi_confd)
  if not ($confd | path exists) { print "no identities yet — run `essentials git-identity sync`"; return }
  let repos = ($nu.home-dir | path join 'repos')
  glob ($confd | path join '*.gitconfig')
    | where {|p| ($p | path basename) != 'identities.gitconfig' }
    | each {|p|
        let e = ($p | path basename | str replace --regex '\.gitconfig$' '')
        {
          entity: $e
          name: (try { ^git config -f $p user.name | str trim } catch { '' })
          email: (try { ^git config -f $p user.email | str trim } catch { '' })
          repo_dir: (($repos | path join $e | path exists))
        }
      }
}

# Abort if any secret (email/name) appears as plaintext in the encrypted blob.
# The .age is binary ciphertext, so a hit means encryption silently failed.
def _gi_assert_encrypted [agefile: string, needles: list<string>] {
  if not ($agefile | path exists) {
    error make { msg: $"expected encrypted file not found: ($agefile)" }
  }
  for needle in $needles {
    if ($needle | str trim | is-empty) { continue }
    if (^grep -aiF $needle $agefile | complete | get exit_code) == 0 {
      error make { msg: $"ABORT: plaintext \"($needle)\" found in ($agefile | path basename) — refusing to commit" }
    }
  }
}

# Encrypt a per-entity file into the dotfiles repo, assert no leak, commit only
# that one .age file, and (unless --no-push) push. Needs chezmoi.
def _gi_persist [entity: string, needles: list<string>, push: bool] {
  if (which chezmoi | is-empty) {
    print $"chezmoi not installed — ~/.config/git/conf.d/($entity).gitconfig saved locally only."
    print "Install chezmoi, then re-run to encrypt + commit + push."
    return
  }
  let pef = (_gi_file $entity)
  ^chezmoi add --encrypt $pef
  let src = (^chezmoi source-path $pef | str trim)
  _gi_assert_encrypted $src $needles
  ^chezmoi git -- add $src
  ^chezmoi git -- commit -m $"secret: ($entity) git identity" -- $src
  if $push {
    ^chezmoi git -- push
    print $"==> encrypted, committed & pushed ($src | path basename) ✔"
  } else {
    print $"==> encrypted & committed ($src | path basename) — push with:  chezmoi git -- push"
  }
}

# Create/overwrite an entity identity, then encrypt + commit + push (--no-push
# to stop before pushing). e.g. essentials git-identity add cuju you@cuju.org
def "essentials git-identity add" [entity: string, email: string, name?: string, --no-push] {
  let confd = (_gi_confd)
  mkdir $confd
  let nm = ($name | default (try { ^git config --global user.name | str trim } catch { '' }))
  let pef = (_gi_file $entity)
  ([$"# git identity for \"($entity)\" — managed via `essentials git-identity`."
    "[user]"
    $"\tname = ($nm)"
    $"\temail = ($email)"
    ""] | str join (char nl)) | save -f $pef
  mkdir ($nu.home-dir | path join 'repos' $entity)
  essentials git-identity sync
  print $"==> wrote ($pef) and ensured ~/repos/($entity)/"
  _gi_persist $entity [$email $nm] (not $no_push)
}

# Edit an entity's identity in $EDITOR; if it changed, re-encrypt + commit + push.
def "essentials git-identity edit" [entity: string, --no-push] {
  let pef = (_gi_file $entity)
  if not ($pef | path exists) {
    print $"no such identity: ($entity). Create it with `essentials git-identity add ($entity) <email>`."
    return
  }
  let before = (open --raw $pef | hash sha256)
  ^$env.EDITOR $pef
  if (open --raw $pef | hash sha256) == $before {
    print "no changes — nothing to commit."
    return
  }
  essentials git-identity sync
  let email = (try { ^git config -f $pef user.email | str trim } catch { '' })
  let nm    = (try { ^git config -f $pef user.name  | str trim } catch { '' })
  _gi_persist $entity [$email $nm] (not $no_push)
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

# --- Tips & docs -----------------------------------------------------------

def _tips_file [] { $nu.home-dir | path join '.config' 'essentials' 'tips.txt' }

# Print one random usage tip (shown on shell startup).
def "essentials tip" [] {
  let f = (_tips_file)
  if not ($f | path exists) { return }
  let tips = (open $f | lines | where {|l| (($l | str trim) != "") and (not ($l | str starts-with "#")) })
  if ($tips | is-empty) { return }
  let t = ($tips | get (random int 0..(($tips | length) - 1)))
  print $"(ansi yellow_bold)💡 tip(ansi reset) ($t) (ansi dark_gray)— `essentials tips` for more(ansi reset)"
}

# List all tips.
def "essentials tips" [] {
  let f = (_tips_file)
  if ($f | path exists) {
    open $f | lines | where {|l| (($l | str trim) != "") and (not ($l | str starts-with "#")) }
      | each {|t| print $"(ansi cyan)•(ansi reset) ($t)" }
  }
}

# Open the cheatsheet (aliases, keybindings, workflows).
def "essentials cheatsheet" [] {
  let f = ($nu.home-dir | path join '.config' 'essentials' 'cheatsheet.md')
  if not ($f | path exists) { print "no cheatsheet found"; return }
  if (which bat | is-not-empty) { ^bat --style=plain --paging=always -l md $f } else { open $f | print }
}

# Bare `essentials` prints help.
def "essentials" [] {
  print "essentials — one command to manage this machine (wraps chezmoi, git, toolchains)"
  print ""
  print "  Dotfiles (local):"
  print "    essentials edit <file>     edit a managed file, then apply it"
  print "    essentials diff            preview pending changes to your home dir"
  print "    essentials apply           apply your local edits to your home dir"
  print "    essentials add <p>         start managing a file  (--encrypt for secrets)"
  print "    essentials forget <p>      stop managing a file"
  print "    essentials show <file>     show a file's fully rendered content"
  print ""
  print "  Dotfiles (remote):"
  print "    essentials pull            get latest from the remote and apply  (↓)"
  print "    essentials save [msg]      stage everything, commit & push        (↑)"
  print "    essentials status          uncommitted changes + pending apply"
  print "    essentials log [n]         recent dotfiles commits"
  print ""
  print "  Maintenance:"
  print "    essentials update          pull + apply + upgrade every toolchain"
  print "    essentials cd              jump into the dotfiles source dir"
  print "    essentials managed         list every managed file"
  print "    essentials doctor          diagnose the setup"
  print ""
  print "  Identities, secrets & hooks:"
  print "    essentials git-identity    per-entity git identities: list|add|edit|sync"
  print "    essentials secrets-setup   generate the age key (once, trusted machine)"
  print "    essentials secret-add <p>  encrypt a file & add it to the repo"
  print "    essentials hooks           global git-hooks: status|enable|disable|test"
  print ""
  print "  Docs:"
  print "    essentials cheatsheet      aliases + keybindings + workflows"
  print "    essentials tip | tips      random / all usage tips"
}
