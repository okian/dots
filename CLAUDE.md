# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [chezmoi](https://chezmoi.io)-managed dotfiles + machine-provisioning repo. One command
bootstraps a fresh macOS or Linux (Ubuntu-first) machine: installs tools, applies all configs,
and runs provisioning scripts. There is no build/test binary — the "program" is the chezmoi
source tree under `home/`, rendered and applied to a real machine.

## Critical layout fact: `.chezmoiroot`

`.chezmoiroot` contains `home`, so **chezmoi's source root is `home/`, not the repo root**.
Every chezmoi path/naming rule below is relative to `home/`. Files at the repo root
(`README.md`, `bootstrap.sh`, `LICENSE`, `.github/`) are plain repo files chezmoi never sees.

## chezmoi naming conventions (how filenames map to targets)

Filenames encode the target path and attributes; the rendered result is what lands in `$HOME`:
- `dot_config/nvim/init.lua` → `~/.config/nvim/init.lua` (`dot_` → `.`)
- `private_dot_ssh/config.tmpl` → `~/.ssh/config`, mode 600 (`private_`), templated (`.tmpl`)
- `executable_commit-msg` → executable bit set
- `encrypted_*.age` → age-decrypted on apply (see Secrets)
- `*.tmpl` → rendered as a Go text/template with chezmoi data before writing

### Script lifecycle prefixes (run order is by filename)
- `run_once_*` — run a single time per machine (keyed by content hash); e.g. macOS defaults, shell change.
- `run_onchange_*` — re-run whenever the rendered content changes. The package installers
  **embed `packages.yaml`** into their rendered output, so editing `packages.yaml` changes the
  hash and auto-triggers re-install. The same trick wires `run_onchange_after_30-editors` to the
  **Doom config** (it embeds `sha256` of `dot_config/doom/*`), so editing `init.el`/`packages.el`/
  `config.el` auto-triggers `doom sync` — enabling a module always installs its package.
- `before_` / `after_` — run before/after the main file-apply phase. Numeric prefixes
  (`00-`, `10-`, …) order them within a phase.

## Single sources of truth

- **`home/.chezmoidata/packages.yaml`** — every package installed via a package manager.
  `brew_formulae` (CLI, both OSes), `brew_casks` (macOS GUI only), `brew_taps` + `mac_brew_formulae`
  (macOS-only taps/formulae, e.g. the `d12frosted/emacs-plus` tap + `emacs-plus@30`), `linux_apt`,
  `linux_flatpak`.
  Languages with version managers (rust→rustup, swift→swiftly, python→uv) are deliberately
  NOT here — they live in `run_onchange_after_20-languages`. Per-language dev tools live here
  too as `go_tools`/`cargo_tools`/`python_tools`/`node_globals`; that same script installs them
  via each language's own installer (`go install`→`~/go/bin`, `cargo`, `uv tool`, `npm -g`), and
  adds Rust's clippy/rustfmt/rust-analyzer as rustup *components*.
- **`home/.chezmoi.toml.tmpl`** — first-run prompts (git name/email, SSH signing) and derived
  template data: `.isMac`, `.isLinux`, `.isUbuntu`, `.hasSecrets`. Prompt answers are stored in
  the local chezmoi config, never committed.

OS/arch branching is done in templates via `.isMac`/`.isLinux`/`.chezmoi.arch` and
`home/.chezmoiignore` (which excludes wrong-OS files, e.g. `Library/` off non-macOS).

## Common commands

```sh
chezmoi diff                       # preview pending changes to $HOME
chezmoi apply                      # apply configs + run due scripts
chezmoi apply --dry-run --force    # render without touching the system
chezmoi execute-template < home/run_onchange_after_20-languages.sh.tmpl   # render one template
chezmoi cat ~/.config/git/config   # show what a target file would render to
chezmoi update                     # git pull + apply
dots update                  # apply + upgrade every toolchain (defined in nushell/dots.nu)
dots upgrade                  # toolchains only, no git pull/apply (shared by the background updater)
dots autoupdate {enable,disable,status,log}   # macOS LaunchAgent that runs `dots upgrade` every 4h
```

## Background auto-update (macOS LaunchAgent)

`home/Library/LaunchAgents/com.kian.dots-autoupdate.plist.tmpl` is a launchd
agent (macOS-only via the `Library/` gate in `.chezmoiignore`) that runs
`dots autoupdate run` → `dots upgrade` every 4h (`StartInterval` 14400s),
logging to `~/.local/state/dots/autoupdate.log`. It upgrades **toolchains only**
— it never does `chezmoi update`/git pull, so it can't apply remote config
unattended. `run_onchange_after_47-autoupdate.sh.tmpl` (re)bootstraps the agent
whenever the rendered plist changes (it embeds the plist's `sha256`, like the
Doom wiring) and creates the log dir. The agent calls nushell with an explicit
`PATH` (launchd's env is minimal) and `source`s `dots.nu` to reach the subcommand.
`dots autoupdate {enable,disable,status,log,now}` are the front-ends.

The `dots` command (nushell) is also the user-facing wrapper over chezmoi for
daily repo management — `dots {edit,diff,apply,add,show,pull,save,status,cd,log,managed,doctor}`
mirror the chezmoi commands above so users never call `chezmoi` directly. When you add a
chezmoi workflow, add the matching `dots` subcommand and a line to the bare-`dots` help.

There is no test suite. **Validation = CI** (`.github/workflows/ci.yml`), which you should
mirror locally before pushing:
1. `chezmoi init --promptDefaults` + `apply --dry-run --force --exclude=scripts,externals` — template lint.
2. Render each `home/run_*.sh.tmpl` via `chezmoi execute-template` and pipe to
   `shellcheck --severity=error --shell=bash`. **All shell in `.sh.tmpl` files must pass shellcheck.**

## Conventions when editing

- Provisioning scripts are **bash**, `set -euo pipefail`, idempotent, and degrade gracefully
  (missing tool → skip, never hard-fail). Guard OS-specific blocks with `{{ if .isMac }}` etc.
- The `dots` command lives in `home/dot_config/nushell/dots.nu` — it's **nushell**,
  not bash. Subcommands are defined as `def "dots <name>" []`.
- To add a tool: edit `packages.yaml` (correct list for its platform), then `chezmoi apply`.
  The installer re-runs automatically. Don't add install logic elsewhere.
- User-facing docs are first-class files surfaced by the `dots` command:
  `home/dot_config/dots/{cheatsheet.md,workflows.md,tips.txt}`. Update them when behavior changes.
- **Personal assets**: fonts live in source-only `home/assets/fonts/` (in `.chezmoiignore`,
  installed by `run_onchange_after_35-fonts` because the target dir differs per OS); DaVinci
  Resolve LUTs/DCTLs and `~/bins` scripts are managed directly under `home/dot_local/...` and
  `home/bins/` (use `executable_`). Empty dirs are held by `.gitkeep` (globally ignored). Fonts
  are Git-LFS tracked via the root `.gitattributes`.

## Secrets (age encryption, public repo)

Secrets are committed as age-encrypted ciphertext. The private key lives at
`~/.config/chezmoi/key.txt` (never committed). `.chezmoiignore` skips all `.secrets`/`.ssh/id_*`
files entirely when that key is absent, so the repo applies cleanly on machines without it.
Add a secret with `dots secret-add <path>` (wraps `chezmoi add --encrypt`).

## Global git hooks

`core.hooksPath = ~/.config/git/hooks` installs hooks for every repo on the machine. They
auto-detect repo languages and run the matching format/lint/test tools; `lib/common.sh` holds
shared helpers and config resolution (`git config hooks.<key>` overrides
`~/.config/git/hooks.conf` defaults). Note: committing directly to a protected branch (`main`,
…) is blocked by default — `git config hooks.allowProtected true` in solo repos. Bypass with
`--no-verify` or `HOOKS_DISABLE=1`.

## Per-entity git identities

Each top-level dir under `~/projects` is an "entity" (work/personal/NGO) with its own git
identity. `home/bins/executable_git-identities-sync` (installed to `~/bins`, on PATH) regenerates
`~/.config/git/conf.d/identities.gitconfig` — one `[includeIf "gitdir:~/projects/<entity>/"]` per
entity dir, each pointing at `conf.d/<entity>.gitconfig`. The global `git/config.tmpl` ends with
`[include] conf.d/identities.gitconfig` so a matching entity's `[user]` overrides the global one.
`run_after_45-git-identities` (a plain `run_`, so it runs **every** apply) invokes the generator;
`dots git-identity {sync,list,add,edit}` are the nushell front-ends. Per-entity files are
created only when missing (never clobbered) and persisted across machines as age-encrypted
`conf.d/*.gitconfig` (gated in `.chezmoiignore` when no key); when `~/projects` is empty those
encrypted entities are recreated as dirs. Don't hand-edit `identities.gitconfig` — it's generated.
The generator also self-heals the global wiring: if `~/.config/git/config` lacks the
`[include] conf.d/identities.gitconfig` line (e.g. a stale global config), it adds it idempotently
(via `git config --file`, matching the template's format so chezmoi sees no diff).

## Color themes (`dots theme`)

`home/dot_config/dots/themes.nu` is the registry (slug → display name, per-tool ids, a 14-colour
palette) **and** the `dots theme {list,set,pick}` commands. `dots theme set <slug>` writes generated,
NOT-chezmoi-managed files under `~/.config/dots/` (`theme`, `palette.json`, `active-theme.sh`,
`starship.toml`) + `~/.config/television/themes/dots.toml`, then live-reloads. Each tool reads those
with a built-in fallback, so nothing breaks before first use:
- **WezTerm** reads `palette.json` → `config.colors`, and `add_to_config_reload_watch_list` makes it hot-reload.
- **nushell** `config.nu` reads the active palette (`_theme_active`) → `color_config` + `BAT_THEME`/`STARSHIP_CONFIG`; television reads a generated `~/.config/television/themes/dots.toml`.
- **zsh** sources `active-theme.sh`; **starship** points `STARSHIP_CONFIG` at the palette-swapped copy (the committed `starship.toml` holds all `[palettes.*]`, stays clean).
- **Neovim** (`plugins/colorscheme.lua`) and **Doom** (`config.el`) read the slug and map it to a real colorscheme; all theme plugins are installed.
`run_after_46-theme` regenerates the active files on every apply (so they exist + re-assert after chezmoi
rewrites managed configs). To add a theme: add a registry entry (palette + nvim/doom/bat/starship ids) and
ensure the nvim plugin + Doom theme exist — the starship `[palettes.<id>]` block is generated from the
registry (only the catppuccin fallback block lives in the committed `starship.toml`).
