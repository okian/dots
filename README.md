# essentials

[![CI](https://github.com/okian/essentials/actions/workflows/ci.yml/badge.svg)](https://github.com/okian/essentials/actions/workflows/ci.yml)

My single source of truth for dotfiles, app/service configuration, and machine
provisioning. One command sets up a fresh macOS or Linux (Ubuntu-first) machine
with everything below, always at the latest version.

## Install (one line)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply github.com/okian/essentials
```

This installs [chezmoi](https://chezmoi.io), clones this repo, prompts once for
your git name/email, then applies all dotfiles and runs the provisioning scripts.

## What you get

| Category    | Tools |
|-------------|-------|
| Shell       | **nushell** (default login shell), zsh (fallback), starship prompt |
| Shell UX    | carapace (completions), atuin (history), direnv, fzf, zoxide |
| Editors     | **neovim + LazyVim**, **Doom Emacs**, tmux (+ tpm) |
| Languages   | rust (rustup), swift (swiftly), go, python (+ uv), node |
| Terminal    | **wezterm** |
| Containers  | **podman** (rootless; `podman machine` on macOS) — no Docker Desktop; `docker`→`podman` shim |
| Fuzzy/nav   | fzf, zoxide, ripgrep, fd, bat, eza |
| Git         | git, git-delta, lazygit, gh, global ignore + commit template |
| AI          | Claude Code CLI |

> On macOS, `run_once_after_70-macos-defaults` applies sane system defaults
> (fast key repeat, show extensions, screenshots → `~/Pictures/Screenshots`, …).
> Pushes are validated by CI (template render + shellcheck).

## How it's organized

| Path | Purpose |
|------|---------|
| `.chezmoiroot` → `home/` | chezmoi source lives under `home/`, keeping the repo root clean |
| `home/.chezmoidata/packages.yaml` | **single source of truth** for all package lists |
| `home/.chezmoi.toml.tmpl` | first-run prompts (git identity); no secrets committed |
| `home/.chezmoiexternal.toml` | external repos kept in sync (Doom Emacs, tpm) |
| `home/run_*` | provisioning scripts, executed in filename order |
| `home/dot_config/*` | per-tool configs (nvim, nushell, doom, wezterm, …) |

OS/arch branching is handled by chezmoi templates (`.chezmoi.os`, `.chezmoi.arch`),
so the same repo drives both platforms.

## Daily use

| Action | Command |
|--------|---------|
| Edit a config | `chezmoi edit ~/.config/nvim/init.lua` |
| Preview pending changes | `chezmoi diff` |
| Apply local edits | `chezmoi apply` |
| Pull latest + apply | `chezmoi update` |
| Capture a machine change back | `chezmoi re-add` then `chezmoi git -- push` |
| Add/remove a package | edit `packages.yaml` → `chezmoi apply` (auto re-installs) |
| **Upgrade everything to latest** | `essentials update` |

`essentials update` runs: `chezmoi update` → `brew upgrade && brew cleanup` →
`rustup update` → `swiftly update` → `uv self update` → neovim plugin sync →
`doom upgrade`.

## Secrets (encrypted, in a public repo)

Secrets (SSH keys, tokens, …) are committed as **age-encrypted ciphertext** — safe
to keep in a public repo. The decryption key lives at a predefined path,
`~/.config/chezmoi/key.txt`, and is **never** committed.

- **Key present** → secrets decrypt and install automatically on `chezmoi apply`.
- **Key absent** → encrypted files are skipped entirely (no prompts, no errors).

### One-time setup (on a trusted machine)

```sh
essentials secrets-setup          # installs age, generates ~/.config/chezmoi/key.txt
                                  # prints your PUBLIC recipient key
```

1. Paste the printed **public** key into `home/.chezmoi.toml.tmpl` → `recipient = "age1…"`, commit, push.
2. Run `chezmoi init` to regenerate the local config with that recipient.
3. **Back up `~/.config/chezmoi/key.txt`** (password manager / USB) — it's the only way to decrypt.

### Encrypt & add a secret

```sh
essentials secret-add ~/.ssh/id_ed25519       # -> stored as encrypted_*.age in the repo
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

Hooks auto-detect repo languages (**go, rust, swift, node, python, jvm** — zero or
more) and run only what applies:

| Hook | What it does |
|------|--------------|
| **pre-commit** | secret scan (gitleaks → regex fallback), large-file guard, block direct commits to protected branches, format-check staged files |
| **commit-msg** | require a ticket key (`ROG-22827`) and/or Conventional Commits; subject length; skips merge/revert/fixup |
| **pre-push** | block force/non-ff (and optionally any) push to protected branches; run lint + the fast test suite |
| **pre-rebase** | refuse to rebase protected or already-published branches |
| **post-checkout / post-merge** | remind (or auto-run) when dependency manifests changed (`go.mod`, `Cargo.toml`, `package.json`, `Package.swift`, `build.gradle.kts`, …) |

Per-language actions: `gofmt`/`go vet`/`golangci-lint`/`go test -short`,
`cargo fmt`/`clippy`/`cargo test`, `swiftformat`/`swiftlint`/`swift test`,
prettier/`<pm> run lint`/`<pm> test`, `ruff`/`pytest`, `ktlint`. Missing tools
degrade to a skip — they never hard-fail a commit.

**Configure** globally in `~/.config/git/hooks.conf`, or per-repo with
`git config hooks.<key> <value>` (full table in that file). **Bypass:**
`git commit/push --no-verify`, `HOOKS_DISABLE=1`, `HOOKS_SKIP_TESTS=1`,
`HOOKS_ALLOW_PROTECTED=1`, `HOOKS_ALLOW_REBASE=1`.

```sh
essentials hooks status         # where they live, on/off, which tools are present
essentials hooks disable        # global kill-switch
git config hooks.allowProtected true    # e.g. let a solo repo commit to main
```

> Heads-up: "block commits to protected branches" is on by default, so in a
> solo repo where you commit straight to `main`, set `git config hooks.allowProtected true`.

## Multi-machine sync

All state lives in this repo. On machine A: edit → `chezmoi git -- push`.
On machine B: `chezmoi update`. Template branches resolve OS differences, so the
same repo just works on both.
