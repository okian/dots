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
  hash and auto-triggers re-install — this is the wiring; nothing else references it.
- `before_` / `after_` — run before/after the main file-apply phase. Numeric prefixes
  (`00-`, `10-`, …) order them within a phase.

## Single sources of truth

- **`home/.chezmoidata/packages.yaml`** — every package installed via a package manager.
  `brew_formulae` (CLI, both OSes), `brew_casks` (macOS GUI only), `linux_apt`, `linux_flatpak`.
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
```

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

Each top-level dir under `~/repos` is an "entity" (work/personal/NGO) with its own git
identity. `home/bins/executable_git-identities-sync` (installed to `~/bins`, on PATH) regenerates
`~/.config/git/conf.d/identities.gitconfig` — one `[includeIf "gitdir:~/repos/<entity>/"]` per
entity dir, each pointing at `conf.d/<entity>.gitconfig`. The global `git/config.tmpl` ends with
`[include] conf.d/identities.gitconfig` so a matching entity's `[user]` overrides the global one.
`run_after_45-git-identities` (a plain `run_`, so it runs **every** apply) invokes the generator;
`dots git-identity {sync,list,add,edit}` are the nushell front-ends. Per-entity files are
created only when missing (never clobbered) and persisted across machines as age-encrypted
`conf.d/*.gitconfig` (gated in `.chezmoiignore` when no key); when `~/repos` is empty those
encrypted entities are recreated as dirs. Don't hand-edit `identities.gitconfig` — it's generated.
The generator also self-heals the global wiring: if `~/.config/git/config` lacks the
`[include] conf.d/identities.gitconfig` line (e.g. a stale global config), it adds it idempotently
(via `git config --file`, matching the template's format so chezmoi sees no diff).
