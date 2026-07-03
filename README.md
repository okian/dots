# dots

[![CI](https://github.com/okian/dots/actions/workflows/ci.yml/badge.svg)](https://github.com/okian/dots/actions/workflows/ci.yml)

My single source of truth for dotfiles, app/service configuration, and machine
provisioning. One command sets up a fresh macOS or Linux (Ubuntu-first) machine
with everything below, always at the latest version.

## Install (one line)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply github.com/okian/dots
```

This installs [chezmoi](https://chezmoi.io), clones this repo, prompts once for
your git name/email, then applies all dotfiles and runs the provisioning scripts.

## What you get

| Category    | Tools |
|-------------|-------|
| Shell       | **nushell** (default login shell), zsh (fallback), starship prompt |
| Shell UX    | carapace (completions), direnv, zoxide, television (history/autocomplete on Ctrl-R/Ctrl-T) |
| Editors     | **neovim + LazyVim**, **Doom Emacs** |
| Languages   | rust (rustup), swift (swiftly), go, python (+ uv), node |
| Dev tools   | per-language LSPs/linters/formatters: clippy·rustfmt·rust-analyzer, goimports·gopls·dlv·gofumpt, pytest·mypy, prettier·eslint·tsc (see `go_tools`/`cargo_tools`/`python_tools`/`node_globals` in `packages.yaml`) |
| Terminal    | **wezterm** (also the multiplexer — splits/panes/tabs, no tmux) |
| Containers  | **colima** (Docker-compatible Lima VM) — no Docker Desktop; native `docker` CLI + `docker-compose`, **dive**, **trivy** (CVE/secret scan) |
| Fuzzy/nav   | **television** (`tv`, fuzzy finder w/ channels), zoxide, ripgrep, fd, bat, eza, **yazi** (file manager w/ previews) |
| Modern CLI  | tldr (tealdeer), just, btop, dust/duf/procs, sd, hyperfine, xh, jless |
| Git         | git, git-delta, lazygit, gh, **difftastic** (`git dft`), **git-absorb**, global ignore + commit template |
| Kubernetes  | kubectl, **k9s** |
| Media       | ffmpeg, imagemagick, exiftool, yt-dlp |
| AI          | Claude Code CLI, ollama |

> On macOS, `run_once_after_70-macos-defaults` applies sane system defaults
> (dark mode, orange accent, fast key repeat, screenshots → `~/Pictures/Screenshots`, …).
> Pushes are validated by CI (template render + shellcheck).

## Principles

A few deliberate choices, so the "why" survives:

- **nushell as the daily shell** (zsh kept as a working fallback) — structured-data
  pipelines over text munging.
- **Per-language version managers** (rustup / swiftly / uv) instead of one umbrella tool —
  each language gets its first-class, always-current toolchain. (`mise` is the unified
  alternative; chosen against on purpose.)
- **colima over Docker Desktop** — open-source Lima VM, no licensing; the stock `docker` CLI talks to it.
- **One theme everywhere** — `dots theme` retints WezTerm, Neovim, Doom, nushell, starship,
  bat and television together from a single palette (default Catppuccin Mocha).
- **`packages.yaml` is the single source of truth** — add a tool there, never in an ad-hoc script.
- **Hooks enforce hygiene globally** (secret scan, protected branches, format/lint/test) with
  easy, explicit bypasses.

## Docs & tips

Everything is integrated around a few habits — `nvim` is the editor everywhere,
`tv`/`fd`/`rg`/`zoxide` for finding things, `lazygit`/`delta` for git.

- **Cheatsheet** — aliases, keybindings, tool reference:
  [`home/dot_config/dots/cheatsheet.md`](home/dot_config/dots/cheatsheet.md)
  (on a set-up machine: `dots cheatsheet`).
- **Workflows & best practices** — how to move/search/edit efficiently:
  [`home/dot_config/dots/workflows.md`](home/dot_config/dots/workflows.md).
- **Tips** — a random one prints on each shell startup (opt out with
  `DOTS_NO_TIPS=1`); `dots tips` lists them all.

## How it's organized

| Path | Purpose |
|------|---------|
| `.chezmoiroot` → `home/` | chezmoi source lives under `home/`, keeping the repo root clean |
| `home/.chezmoidata/packages.yaml` | **single source of truth** for all package lists |
| `home/.chezmoi.toml.tmpl` | first-run prompts (git identity); no secrets committed |
| `home/.chezmoiexternal.toml` | external repos kept in sync (Doom Emacs) |
| `home/run_*` | provisioning scripts, executed in filename order |
| `home/dot_config/*` | per-tool configs (nvim, nushell, doom, wezterm, …) |

OS/arch branching is handled by chezmoi templates (`.chezmoi.os`, `.chezmoi.arch`),
so the same repo drives both platforms.

## Personal assets (fonts, DaVinci Resolve, scripts)

Drop your own files into these locations, then `chezmoi apply` (or `dots update`):

| Asset | Put files in | Lands at | How |
|-------|--------------|----------|-----|
| **Fonts** (`.ttf`/`.otf`/`.ttc`) | `home/assets/fonts/` | `~/Library/Fonts` (macOS) · `~/.local/share/fonts` (Linux) | `run_onchange_after_35-fonts` copies them, rebuilds the font cache on Linux |
| **DaVinci Resolve** (LUTs `.cube`/`.3dl`, DCTLs `.dctl`, …) | `home/dot_local/share/davinci-resolve/{LUT,DCTL}/` | `~/.local/share/davinci-resolve/…` | managed directly. **One-time:** add that folder in Resolve → *Preferences → System → LUT* (DCTLs in it are picked up too) |
| **Personal scripts** | `home/bins/` (name each `executable_<name>`) | `~/bins/` (on `PATH`) | managed directly: `executable_foo` → `~/bins/foo`, +x. Append `.tmpl` to template one |

- **Fonts use Git LFS** (`.gitattributes` tracks `*.ttf/*.otf/*.ttc`) — versions large binaries cleanly and keeps them under the pre-commit large-file guard. `git lfs install` runs globally via the editors script.
- **Empty for now:** each dir holds a `.gitkeep` placeholder (ignored, never written to `$HOME`); real files take over.
- **`assets/` is source-only** (in `.chezmoiignore`) — the fonts script reads it from the repo instead of copying it into `$HOME`.
- **Secret inside a script?** Don't commit it in the clear — `dots secret-add <file>` encrypts it first.

## Daily use

| Action | Command |
|--------|---------|
| Edit a config | `dots edit ~/.config/nvim/init.lua` (edits source + applies) |
| Preview pending changes | `dots diff` |
| Apply local edits | `dots apply` |
| Pull latest + apply | `dots pull` |
| Capture a machine change back | `dots readd` then `dots save` |
| Add/remove a package | `dots packages` (edits `packages.yaml`, auto re-installs) |
| **Upgrade everything to latest** | `dots update` |

`dots update` runs: `chezmoi update` → `brew upgrade && brew cleanup` →
`rustup update` → `swiftly update` → uv python/tools → npm globals →
cargo/go tools → neovim plugin sync → `doom upgrade`. On macOS a LaunchAgent
repeats the toolchain half every 4h (`dots autoupdate`), formulae-only so
GUI apps are never swapped while running.

## Secrets (encrypted, in a public repo)

Secrets (SSH keys, tokens, …) are committed as **age-encrypted ciphertext** — safe
to keep in a public repo. The decryption key lives at a predefined path,
`~/.config/chezmoi/key.txt`, and is **never** committed.

- **Key present** → secrets decrypt and install automatically on `chezmoi apply`.
- **Key absent** → encrypted files are skipped entirely (no prompts, no errors).

### One-time setup (on a trusted machine)

```sh
dots secrets-setup          # installs age, generates ~/.config/chezmoi/key.txt
                                  # prints your PUBLIC recipient key
```

1. Paste the printed **public** key into `home/.chezmoi.toml.tmpl` → `recipient = "age1…"`, commit, push.
2. Run `chezmoi init` to regenerate the local config with that recipient.
3. **Back up `~/.config/chezmoi/key.txt`** (password manager / USB) — it's the only way to decrypt.

### Encrypt & add a secret

```sh
dots secret-add ~/.ssh/id_ed25519       # -> stored as encrypted_*.age in the repo
chezmoi git -- add . ; chezmoi git -- commit -m "add ssh key" ; chezmoi git -- push
```

### Use on another trusted machine

Copy `key.txt` to `~/.config/chezmoi/key.txt` (out-of-band), then run the install
one-liner — secrets decrypt automatically. Public/shared machines simply skip them.

> Convention: secrets land under `~/.ssh/id_*` (private keys) or `~/.secrets/`. Those
> paths are auto-skipped when the key is missing (see `home/.chezmoiignore`).

## Global git hooks

A single global hooks directory (`core.hooksPath = ~/.config/git/hooks`) runs on
**every** repo — new and cloned — with no per-repo setup. Repos that manage their
own hooks (husky / pre-commit framework) set a local `core.hooksPath` that
transparently overrides this; otherwise the global hooks also **chain** to any
`.git/hooks/<name>` or `.husky/<name>` they find.

Hooks auto-detect repo languages (**go, rust, swift, node, python, jvm, shell,
docker, terraform, k8s** — zero or more) and run only what applies:

| Hook | What it does |
|------|--------------|
| **pre-commit** | secret scan (gitleaks → regex fallback), large-file guard, block direct commits to protected branches, format/lint staged files, spell-check (typos), validate k8s manifests (kubeconform) |
| **prepare-commit-msg** | auto-insert the branch's ticket key into the subject (`feat/ROG-1-x` → `ROG-1: …`) |
| **commit-msg** | require a ticket key (`ROG-22827`) and/or Conventional Commits; subject length; skips merge/revert/fixup |
| **pre-push** | block force/non-ff (and optionally any) push to protected branches, block WIP/fixup commits, run lint + the fast test suite |
| **pre-rebase** | refuse to rebase protected or already-published branches |
| **post-checkout / post-merge** | remind (or auto-run) when dependency manifests changed (`go.mod`, `Cargo.toml`, `package.json`, `Package.swift`, `build.gradle.kts`, …) |

Per-language actions: `gofumpt`/`goimports`/`golangci-lint`/`staticcheck`/`go test -short`/`go mod tidy`,
`cargo fmt`/`clippy`/`cargo test`, `swiftformat`/`swiftlint`/`swift test`,
prettier/`<pm> run lint`/`<pm> test`, `ruff`/`pytest`, `ktlint`, shell
`shellcheck` (+ opt-in `shfmt`), `hadolint`, `tofu fmt`/`tflint`/`trivy config`,
`kubeconform`/`helm lint`/`conftest`. Missing tools degrade to a skip — they
never hard-fail a commit.

**Default linter configs.** When a repo has no linter config of its own, the
hooks apply a shipped **conservative** default (`~/.config/git/hooks/linters/`)
so bare repos get a uniform, sensible baseline instead of each tool's built-in
behavior. A repo-local config **always wins** (e.g. `.golangci.yml`,
`ruff.toml`, or `[tool.ruff]` in `pyproject.toml`). Currently shipped:
golangci-lint (v2 — the `standard` set plus `bodyclose`/`misspell`/`unconvert`)
and ruff (`E`/`F`/`W`/`I`). Turn defaults off with
`git config hooks.useDefaultLinterConfig false`.

**Configure** globally in `~/.config/git/hooks.conf`, or per-repo with
`git config hooks.<key> <value>` (full table in that file). **Bypass:**
`git commit/push --no-verify`, `HOOKS_DISABLE=1`, `HOOKS_SKIP_TESTS=1`,
`HOOKS_ALLOW_PROTECTED=1`, `HOOKS_ALLOW_REBASE=1`.

```sh
dots hooks status         # where they live, on/off, which tools are present
dots hooks disable        # global kill-switch
git config hooks.allowProtected true    # e.g. let a solo repo commit to main
```

> Heads-up: "block commits to protected branches" is on by default, so in a
> solo repo where you commit straight to `main`, set `git config hooks.allowProtected true`.

## Multi-machine sync

All state lives in this repo. On machine A: edit → `chezmoi git -- push`.
On machine B: `chezmoi update`. Template branches resolve OS differences, so the
same repo just works on both.

## Troubleshooting & recovery

| Symptom | Fix |
|---------|-----|
| `chezmoi apply` failed partway | It's idempotent — just re-run `chezmoi apply`. Inspect first with `chezmoi diff`. |
| A `run_onchange_` script won't re-run after I edited what it installs | It only re-runs when its *rendered* content changes. Force every one: `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`. |
| A managed dotfile got hand-edited and looks wrong | `dots apply` overwrites it back to repo state. To keep the local change instead: `dots readd`. |
| A git hook is blocking a commit/push I need to land | One-off: `git commit/push --no-verify`. Skip just tests: `HOOKS_SKIP_TESTS=1 git push`. All hooks off: `dots hooks disable`. |
| Committing to `main` is blocked | Expected. Branch (`git switch -c feat/ROG-123-x`) or, for a solo repo, `git config hooks.allowProtected true`. |
| New fonts don't show up | `chezmoi apply` (runs the font script). Linux: `fc-cache -f`. macOS: reopen the app. Check `~/Library/Fonts` / `~/.local/share/fonts`. |
| `command not found` right after install | Open a new shell. Go tools live in `~/go/bin`, cargo in `~/.cargo/bin`, your scripts in `~/bins` — all added to `PATH` at login. |
| Want zsh back as the login shell | `chsh -s "$(command -v zsh)"`, then open a new terminal. nushell stays installed. |
| Neovim misbehaving | `nvim` → `:checkhealth`; refresh plugins with `:Lazy sync`; add language support with `:LazyExtras`. |
| Secrets didn't decrypt | The age key must be at `~/.config/chezmoi/key.txt`. Without it, encrypted files are skipped by design (no error). |
| Forgot a keybinding in Neovim | Press `Space` and wait — **which-key** lists every leader binding. |
