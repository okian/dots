# `dots` command — one-shot update of configs + every toolchain.
# Usage:  dots update

# Run one upgrade step; report (never abort) if its tool is missing or it fails.
def _step [label: string, work: closure] {
  print $"==> ($label)"
  try { do $work } catch {|e| print $"   ! skipped: ($e.msg)" }
}

# Upgrade every toolchain in place (no git pull / config apply). Shared by
# `dots update` and the background auto-updater (`dots autoupdate`), which
# passes --formulae-only: an unattended `brew upgrade` would also replace GUI
# app bundles (wezterm, zed, …) while they're running — casks only upgrade
# when a human runs `dots update`.
def "dots upgrade" [--formulae-only] {
  if $formulae_only {
    _step "brew upgrade (formulae only)" { ^brew upgrade --formula; ^brew cleanup }
  } else {
    _step "brew upgrade" { ^brew upgrade; ^brew cleanup }
  }
  _step "rustup update" { ^rustup update }
  _step "swiftly update" { ^swiftly update --assume-yes }
  _step "uv: install latest python (uv itself updated by brew above)" { ^uv python install }
  _step "uv tools upgrade (pytest, mypy, …)" { ^uv tool upgrade --all }
  _step "npm global tools update" { ^npm update -g }
  _step "cargo tools update (cargo install-update)" { ^cargo install-update -a }
  _step "go tools update (gup)" { ^gup update }
  _step "neovim plugin sync" { ^nvim --headless "+Lazy! sync" +qa }
  _step "doom upgrade" {
    let doom = ($nu.home-dir | path join '.config' 'emacs' 'bin' 'doom')
    if ($doom | path exists) { ^$doom upgrade --force }
  }
}

def "dots update" [] {
  _step "chezmoi update (pull configs + apply)" { ^chezmoi update }
  dots upgrade
  print "==> done. Everything is at latest."
}

# --- Background auto-update (macOS LaunchAgent, every 4h) -------------------
# A chezmoi-managed LaunchAgent (~/Library/LaunchAgents/com.kian.dots-autoupdate
# .plist) runs `dots autoupdate run` on a timer; these subcommands manage it.
# It only upgrades toolchains — it never pulls/applies config unattended.
const autoupdate_label = "com.kian.dots-autoupdate"

def _autoupdate_plist [] {
  $nu.home-dir | path join 'Library' 'LaunchAgents' $"($autoupdate_label).plist"
}
def _autoupdate_log [] {
  $nu.home-dir | path join '.local' 'state' 'dots' 'autoupdate.log'
}
def _autoupdate_domain [] { $"gui/(^id -u | str trim)" }

# Keep the log bounded: launchd appends to it forever, so past ~512KB keep only
# the tail. Truncate IN PLACE (shell `>`), never replace the file — launchd
# holds an open fd on it, and a new inode would orphan every future write.
def _autoupdate_rotate [] {
  let log = (_autoupdate_log)
  if not ($log | path exists) { return }
  if ((ls $log | first | get size) < 512kb) { return }
  let tmp = (mktemp -t "dots-autoupdate.XXXXX")
  (open --raw $log | lines | last 2000 | str join "\n") + "\n" | save -f $tmp
  ^sh -c $"cat '($tmp)' > '($log)'"
  rm -f $tmp
}

# Invoked by launchd: one timestamped, unattended upgrade pass (CLI toolchains
# only — casks wait for an interactive `dots update`).
def "dots autoupdate run" [] {
  _autoupdate_rotate
  print $"================ dots autoupdate (date now | format date '%Y-%m-%d %H:%M:%S') ================"
  dots upgrade --formulae-only
  print "==> autoupdate done."
}

# Run an upgrade pass now, in the foreground (same work the timer does).
def "dots autoupdate now" [] { dots upgrade }

# (Re)load the LaunchAgent so the 4-hourly timer is active.
def "dots autoupdate enable" [] {
  let plist = (_autoupdate_plist)
  if not ($plist | path exists) {
    print "plist not installed yet — run `dots apply` first."; return
  }
  let domain = (_autoupdate_domain)
  try { ^launchctl bootout $domain $plist } catch { }
  ^launchctl bootstrap $domain $plist
  print $"==> enabled — upgrades every 4h. Log: (_autoupdate_log)"
}

# Stop the timer (unload the LaunchAgent).
def "dots autoupdate disable" [] {
  try { ^launchctl bootout (_autoupdate_domain) (_autoupdate_plist) } catch { }
  print "==> disabled."
}

# Is the timer loaded — and when did it last run, with what result?
def "dots autoupdate status" [] {
  let hit = (^launchctl list | lines | find $autoupdate_label)
  if ($hit | is-empty) { print "not loaded — run `dots autoupdate enable`."; return }
  print "loaded:    yes (runs every 4h)"
  let exit_line = (try {
    ^launchctl print $"(_autoupdate_domain)/($autoupdate_label)" err> /dev/null
      | lines | where {|l| $l | str contains "last exit code" } | first | str trim
  } catch { "" })
  if ($exit_line | is-not-empty) { print $"($exit_line)" }
  let log = (_autoupdate_log)
  if not ($log | path exists) { print "log:       none yet (timer hasn't fired)"; return }
  let banners = (open --raw $log | lines
    | where {|l| $l | str starts-with "================ dots autoupdate" })
  if ($banners | is-not-empty) {
    let ts = ($banners | last | str replace --all '=' '' | str trim
      | str replace 'dots autoupdate ' '')
    print $"last run:  ($ts)"
  }
  print $"log:       ($log) ((ls $log | first | get size))"
}

# Tail the auto-update log.
def "dots autoupdate log" [n: int = 40] {
  let log = (_autoupdate_log)
  if not ($log | path exists) { print "no log yet (timer hasn't run)."; return }
  open $log | lines | last $n | str join "\n" | print
}

# --- Repo / dotfiles management (one command, no raw chezmoi) ---------------
# Mental model:  edit → diff → apply  (local);  pull ↓ / save ↑  (remote).

# Guard: abort with a clear message if chezmoi isn't installed. One line at the
# top of each command that needs it (replaces the old print-and-return dance).
def _need [] {
  if (which chezmoi | is-empty) {
    error make --unspanned { msg: "chezmoi is not installed on this machine." }
  }
}

# Preview what applying would change in $HOME.
def "dots diff" [] { _need; ^chezmoi diff }

# Apply your local source edits to $HOME.
def "dots apply" [] { _need; ^chezmoi apply; print "==> applied." }

# Edit a managed file (edits the source, then applies it). e.g. dots edit ~/.config/git/config
def "dots edit" [...file: string] {
  _need
  if ($file | is-empty) { print "usage: dots edit <file> [<file> …]"; return }
  ^chezmoi edit --apply ...$file
}

# Show the fully rendered content a target file would have.
def "dots show" [file: string] { _need; ^chezmoi cat $file }

# Start managing an existing file (copy it into the repo). For secrets: dots secret-add.
def "dots add" [path: string] {
  _need
  ^chezmoi add $path
  print $"==> now managing ($path)."
}

# Stop managing a file (leaves it in $HOME, removes it from the repo).
def "dots forget" [path: string] { _need; ^chezmoi forget $path }

# Capture machine-local edits to managed files back into the repo (the reverse
# of apply). No args = every modified managed file; or name specific ones.
def "dots readd" [...path: string] {
  _need
  ^chezmoi re-add ...$path
  print "==> captured local change(s) into the repo — review: `dots status`, publish: `dots save`."
}

# Edit packages.yaml — the single source of truth for installed tools — and
# apply if it changed (the run_onchange installers re-run automatically).
# It lives in .chezmoidata/, which `dots edit` can't reach (not a managed target).
def "dots packages" [] {
  _need
  let f = (^chezmoi source-path | str trim | path join '.chezmoidata' 'packages.yaml')
  let before = (open --raw $f | hash sha256)
  ^$env.EDITOR $f
  if (open --raw $f | hash sha256) == $before { print "no changes."; return }
  ^chezmoi apply
  print "==> applied — installers re-ran for the changed lists."
}

# Pull the latest from the remote and apply (git pull + apply). The downward
# counterpart to `save`. (`dots update` also upgrades every toolchain.)
def "dots pull" [] { _need; ^chezmoi update; print "==> pulled & applied." }

# Save ALL local repo changes upward: stage everything, commit, push.
def "dots save" [message?: string] {
  _need
  # The repo's own global hooks would block this on a fresh machine: a direct
  # commit to `main`, with no ticket key in the default message. This is the
  # documented solo-repo escape hatch — set it repo-locally, once.
  if (^chezmoi git -- config --get hooks.allowProtected | complete | get exit_code) != 0 {
    ^chezmoi git -- config hooks.allowProtected true
    ^chezmoi git -- config hooks.ticketRequired false
  }
  let dirty = (^chezmoi git -- status --porcelain | str trim)
  if ($dirty | is-empty) { print "nothing to save — the repo is clean."; return }
  ^chezmoi git -- add -A
  ^chezmoi git -- commit -m ($message | default "update dotfiles")
  ^chezmoi git -- push
  print "==> saved (committed & pushed)."
}

# Overview: repo git status + a summary of pending changes to apply.
def "dots status" [] {
  _need
  print "── repo (uncommitted changes) ──"
  ^chezmoi git -- status -sb
  print ""
  print "── pending apply (chezmoi diff) ──"
  let d = (^chezmoi diff | str trim)
  if ($d | is-empty) { print "  (none — $HOME matches the repo)" } else { print $d }
}

# Jump into the dotfiles source directory.
def --env "dots cd" [] { _need; cd (^chezmoi source-path | str trim) }

# Recent commit history of the dotfiles repo.
def "dots log" [n: int = 15] { _need; ^chezmoi git -- log --oneline -n $n }

# List every file this repo manages.
def "dots managed" [] { _need; ^chezmoi managed }

# Diagnose the setup: chezmoi's own checks, then this repo's machinery on top
# (the layers `chezmoi doctor` knows nothing about).
def "dots doctor" [] {
  _need
  ^chezmoi doctor
  print ""
  print "── dots checks ──"
  let chk = {|cond, label, hint|
    if $cond { print $"  ✓ ($label)" } else { print $"  ! ($label) — ($hint)" }
  }
  do $chk (($nu.home-dir | path join '.config' 'chezmoi' 'key.txt') | path exists) "age key present" "secrets are skipped on this machine (fine if intended); `dots secrets-setup`"
  do $chk ((^git config --global --get core.hooksPath | complete | get stdout | str trim | str ends-with '.config/git/hooks')) "global git hooks wired" "run `dots apply` (sets core.hooksPath)"
  do $chk (($nu.home-dir | path join '.config' 'git' 'conf.d' 'identities.gitconfig') | path exists) "per-entity git identities generated" "run `dots git-identity sync`"
  do $chk (($nu.home-dir | path join '.config' 'dots' 'theme') | path exists) "color theme generated" "run `dots theme` to pick one"
  let vendor = ($nu.data-dir | path join 'vendor' 'autoload')
  do $chk ((['starship.nu' 'zoxide.nu' 'carapace.nu' 'tv.nu'] | all {|f| ($vendor | path join $f | path exists) })) "shell integrations generated (starship/zoxide/carapace/tv)" "run `dots apply`"
  do $chk (($nu.user-autoload-dirs | first | path join 'zi-tv.nu') | path exists) "tv-backed `zi` override" "run `dots apply`"
  if ($nu.os-info.name == 'macos') {
    do $chk ((^launchctl list | lines | find $autoupdate_label | is-not-empty)) "autoupdate timer loaded" "run `dots autoupdate enable`"
  }
}

# --- Secrets (age encryption) ----------------------------------------------

# One-time: generate the age keypair on a trusted machine.
def "dots secrets-setup" [] {
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
def "dots secret-add" [path: string] {
  _need
  ^chezmoi add --encrypt $path
  print $"==> Encrypted and staged ($path)."
  print "Commit & push:  chezmoi git -- add . ; chezmoi git -- commit -m secret ; chezmoi git -- push"
}

# --- Per-entity git identities (driven by ~/projects) ----------------------
# Each top-level dir under ~/projects is an entity (work, personal, NGO…) with
# its own git identity. See ~/bins/git-identities-sync for the full mechanism.

def _gi_confd [] { $nu.home-dir | path join '.config' 'git' 'conf.d' }
def _gi_file [entity: string] { (_gi_confd) | path join $"($entity).gitconfig" }

# Regenerate the includeIf blocks from the current ~/projects layout.
def "dots git-identity sync" [] {
  let bin = ($nu.home-dir | path join 'bins' 'git-identities-sync')
  if ($bin | path exists) { ^$bin } else { print "git-identities-sync not installed — run `chezmoi apply`" }
}

# List entities, their resolved identity, and whether a ~/projects dir exists.
def "dots git-identity list" [] {
  let confd = (_gi_confd)
  if not ($confd | path exists) { print "no identities yet — run `dots git-identity sync`"; return }
  let repos = ($nu.home-dir | path join 'projects')
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
# to stop before pushing). e.g. dots git-identity add cuju you@cuju.org
def "dots git-identity add" [entity: string, email: string, name?: string, --no-push] {
  let confd = (_gi_confd)
  mkdir $confd
  let nm = ($name | default (try { ^git config --global user.name | str trim } catch { '' }))
  let pef = (_gi_file $entity)
  ([$"# git identity for \"($entity)\" — managed via `dots git-identity`."
    "[user]"
    $"\tname = ($nm)"
    $"\temail = ($email)"
    ""] | str join (char nl)) | save -f $pef
  mkdir ($nu.home-dir | path join 'projects' $entity)
  dots git-identity sync
  print $"==> wrote ($pef) and ensured ~/projects/($entity)/"
  _gi_persist $entity [$email $nm] (not $no_push)
}

# Edit an entity's identity in $EDITOR; if it changed, re-encrypt + commit + push.
def "dots git-identity edit" [entity: string, --no-push] {
  let pef = (_gi_file $entity)
  if not ($pef | path exists) {
    print $"no such identity: ($entity). Create it with `dots git-identity add ($entity) <email>`."
    return
  }
  let before = (open --raw $pef | hash sha256)
  ^$env.EDITOR $pef
  if (open --raw $pef | hash sha256) == $before {
    print "no changes — nothing to commit."
    return
  }
  dots git-identity sync
  let email = (try { ^git config -f $pef user.email | str trim } catch { '' })
  let nm    = (try { ^git config -f $pef user.name  | str trim } catch { '' })
  _gi_persist $entity [$email $nm] (not $no_push)
}

# --- Global git hooks ------------------------------------------------------

# Show hook status (where they live, enabled?, available tools).
def "dots hooks status" [] {
  let path = (^git config --global --get core.hooksPath | str trim)
  print $"hooksPath: ($path)"
  let disabled = (^git config --global --get hooks.disable | str trim)
  print $"enabled:   (if $disabled == 'true' { 'no (hooks.disable=true)' } else { 'yes' })"
  print "tools:"
  for t in [gitleaks golangci-lint staticcheck gofumpt ruff swiftlint swiftformat ktlint shellcheck shfmt hadolint tofu tflint trivy kubeconform helm conftest typos git-lfs] {
    print $"  (if (which $t | is-not-empty) { '✓' } else { '·' }) ($t)"
  }
}

# Turn all hooks off / on globally.
def "dots hooks disable" [] { ^git config --global hooks.disable true; print "global hooks disabled" }
def "dots hooks enable"  [] { ^git config --global --unset hooks.disable; print "global hooks enabled" }

# Run the pre-commit hook now against staged changes (dry test).
def "dots hooks test" [] {
  let h = (^git config --global --get core.hooksPath | str trim | path join 'pre-commit')
  if ($h | path exists) { ^$h } else { print "no pre-commit hook found" }
}

# --- Tips & docs -----------------------------------------------------------

def _tips_file [] { $nu.home-dir | path join '.config' 'dots' 'tips.txt' }

# Tips file lines, minus blanks and comments.
def _tips_lines [] {
  let f = (_tips_file)
  if not ($f | path exists) { return [] }
  open $f | lines | where {|l| (($l | str trim) != "") and (not ($l | str starts-with "#")) }
}

# Print one random usage tip (shown on shell startup).
def "dots tip" [] {
  let tips = (_tips_lines)
  if ($tips | is-empty) { return }
  let t = ($tips | shuffle | first)
  print $"(ansi yellow_bold)💡 tip(ansi reset) ($t) (ansi dark_gray)— `dots tips` for more(ansi reset)"
}

# List all tips.
def "dots tips" [] {
  _tips_lines | each {|t| print $"(ansi cyan)•(ansi reset) ($t)" }
}

# Open the cheatsheet (aliases, keybindings, workflows).
def "dots cheatsheet" [] {
  let f = ($nu.home-dir | path join '.config' 'dots' 'cheatsheet.md')
  if not ($f | path exists) { print "no cheatsheet found"; return }
  if (which bat | is-not-empty) { ^bat --style=plain --paging=always -l md $f } else { open $f | print }
}

# Bare `dots` prints help.
def "dots" [] {
  print "dots — one command to manage this machine (wraps chezmoi, git, toolchains)"
  print ""
  print "  Dotfiles (local):"
  print "    dots edit <file>     edit a managed file, then apply it"
  print "    dots diff            preview pending changes to your home dir"
  print "    dots apply           apply your local edits to your home dir"
  print "    dots add <p>         start managing a file  (secrets: dots secret-add)"
  print "    dots readd [p]       capture local edits to managed files back into the repo"
  print "    dots forget <p>      stop managing a file"
  print "    dots show <file>     show a file's fully rendered content"
  print ""
  print "  Dotfiles (remote):"
  print "    dots pull            get latest from the remote and apply  (↓)"
  print "    dots save [msg]      stage everything, commit & push        (↑)"
  print "    dots status          uncommitted changes + pending apply"
  print "    dots log [n]         recent dotfiles commits"
  print ""
  print "  Appearance:"
  print "    dots theme           pick a color theme (tv) — retints every tool"
  print "    dots theme list      list themes;  dots theme set <name> to switch"
  print ""
  print "  Maintenance:"
  print "    dots update          pull + apply + upgrade every toolchain"
  print "    dots upgrade         upgrade toolchains only (no pull/apply)"
  print "    dots packages        edit packages.yaml; auto-applies if changed"
  print "    dots autoupdate      background 4-hourly upgrades: enable|disable|status|log"
  print "    dots cd              jump into the dotfiles source dir"
  print "    dots managed         list every managed file"
  print "    dots doctor          diagnose the setup"
  print ""
  print "  Identities, secrets & hooks:"
  print "    dots git-identity    per-entity git identities: list|add|edit|sync"
  print "    dots secrets-setup   generate the age key (once, trusted machine)"
  print "    dots secret-add <p>  encrypt a file & add it to the repo"
  print "    dots hooks           global git-hooks: status|enable|disable|test"
  print ""
  print "  Docs:"
  print "    dots cheatsheet      aliases + keybindings + workflows"
  print "    dots tip | tips      random / all usage tips"
}
