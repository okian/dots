# dots — workflows & best practices

How to combine the tools in this setup to move, search, and edit fast. These are
patterns, not rules — steal what fits.

## Moving around

- **Don't `cd` by hand across the tree.** Use `z` (zoxide): after visiting a
  directory once, `z proj`, `z ess`, `z dot` jump straight there by a fragment of
  the path. `zi` gives an interactive picker when several match.
- **Fuzzy-jump when you don't remember the name:** `fcd` opens a television
  picker of subdirectories with a tree preview.
- **Browse when you'd rather look:** `y` opens yazi (file manager with previews);
  quitting cd's your shell to where you were. Inside it, `z` fuzzy-jumps to any
  file/dir and `Z` to a frecent dir — both through television.
- **Split inside WezTerm** instead of opening new windows: `Ctrl-Space \` / `-`
  to split. `Ctrl-h/j/k/l` moves seamlessly between WezTerm panes *and* Neovim
  splits — the same four keys whether the neighbour is a shell or an editor.
- **`cd -` toggles** between the last two directories.

## Searching

A two-step rhythm beats scrolling: **filter to candidates, then act.**

- **Content search:** `rg "pattern"` — fast, respects `.gitignore`. Scope by type
  (`rg -t rust TODO`), show context (`-C3`), list files only (`-l`).
- **Filename search:** `fd name` — skips `.git` and ignored files by default.
- **History:** `Ctrl-R` (television) — fuzzy, filters as you type. Type any
  fragment of a command you ran days ago. Far better than arrow-up spamming.
  `Ctrl-T` fuzzy-completes the command you're typing.
- **Find-then-edit in one move:** `ff` lists files through television with a bat
  preview and opens your pick in Neovim. For content, `tv text` greps and prints,
  or do it inside the editor: `nvim` then `<leader>/` (or `<leader>sv` for tv).
- **Jump to a symbol (terminal):** `fsym` (or `tv symbols`) fuzzy-searches the
  current project's classes/functions/variables via universal-ctags — the preview
  scrolls to the definition and Enter opens Neovim there. Filter by symbol name,
  kind, or file path; it's the terminal twin of Neovim's LSP symbol search.
- **Jump to a project:** `proj` (or `tv projects`) lists git repos under
  `~/projects` with a README/tree preview; Enter cd's in, `Ctrl-S` opens that
  repo's symbols, `Ctrl-E` opens it in Neovim.
- **Pipe into `tv`** whenever a command spits a long list:
  `git branch | tv`, `brew leaves | tv`, `rg -l TODO | tv`.
- **Cheatsheets:** `tv tldr` fuzzy-browses tldr pages; `tldr <cmd>` prints one.

## Editing

- **Neovim is the editor everywhere** — `$EDITOR`, `$GIT_EDITOR`, and
  `$KUBE_EDITOR` all point at it. Learn it once, use it for commit messages,
  `kubectl edit`, rebases, everything.
- **Inside Neovim (LazyVim):** `<leader>ff` to open files, `<leader>/` to grep,
  `gd`/`gr` to navigate code, `K` for docs, `<leader>ca` for fixes, `<leader>cr` to
  rename across the project, `<leader>cf` to format. `:checkhealth` if something's off.
- **Don't reformat blindly on commit.** The pre-commit hook *checks* formatting and
  lints staged files (Go/Rust/Node/Python, plus shell `shellcheck`, `hadolint` for
  Dockerfiles, `tofu fmt`/`tflint`, `kubeconform`, and a `typos` spell-check) — it
  never rewrites your partial staging. If it complains, run the fixer it names
  (`gofumpt -w`, `cargo fmt`, `<pm> run format`, `typos -w`) and re-stage.

## Git

- **Branch, don't commit to `main`.** `git switch -c feat/ROG-1234-thing`. Direct
  commits to protected branches are blocked by the hook.
- **Ticket keys are auto-inserted from your branch.** Branch as
  `feat/ROG-1234-thing` and `ROG-1234: ` is prepended to your subject for you. The
  commit-msg hook still enforces one if the branch has none; the body is free-form.
- **Use lazygit (`lg`) for the messy parts** — stage individual hunks, amend,
  reorder, resolve conflicts visually. `git lg` (alias) shows a graph log.
- **Diffs are rendered by delta** automatically — side-by-side, syntax-highlighted.
- **Pushing runs lint + fast tests** for the repo's languages, and **blocks
  WIP/fixup! commits** (finish or `git rebase -i --autosquash` first). Skip tests
  with `HOOKS_SKIP_TESTS=1 git push`, or everything with `git push --no-verify`.
- **Force-pushing to a protected branch is blocked** — a safety net before CI.

## Secrets

- **Never paste a secret into a tracked file.** The pre-commit secret scan
  (gitleaks → regex fallback) will block it.
- **To version a secret,** encrypt it: `dots secret-add ~/.ssh/id_ed25519`
  stores ciphertext (`encrypted_*.age`) that's safe in a public repo. It only
  decrypts on machines that hold `~/.config/chezmoi/key.txt` — back that key up.

## Keeping the machine current

- **One command:** `dots update` — pulls config changes and upgrades brew,
  rust, swift, uv/python, Neovim plugins, and Doom. `dots upgrade` does the
  toolchain half only (no git pull / config apply).
- **Hands-off (macOS):** a LaunchAgent runs `dots upgrade --formulae-only` every
  4 hours in the background — CLI toolchains only; GUI casks wait for an
  interactive `dots update` so a running app is never swapped underneath you.
  `dots autoupdate status` shows the timer, last run and log; `dots autoupdate
  log` tails it; `disable`/`enable` turns it off/on. It never pulls or applies
  config unattended.
- **Change configs the dots way:** `dots edit ~/.config/nvim/init.lua` edits the
  source and applies it. To preview, `dots diff`. Never hand-edit a managed file
  in place — your next `apply` would revert it.
- **Capture a machine-local tweak** back into the repo with `dots readd`, then
  `dots save` so every machine gets it.
- **Add or drop a tool** with `dots packages` — packages.yaml is the single
  source of truth, and the installers re-run automatically when it changes.

## A few muscle-memory combos

```sh
z api && ff                  # jump to a project, fuzzy-open a file in nvim
rg -l "TODO" | tv | xargs nvim   # pick among files containing TODO, edit it
git switch -c fix/ROG-22-null && lg   # branch, then stage+commit in lazygit
dots edit ~/.zshrc               # tweak a dotfile (edits source + applies)
```
