# dots — workflows & best practices

How to combine the tools in this setup to move, search, and edit fast. These are
patterns, not rules — steal what fits.

## Moving around

- **Don't `cd` by hand across the tree.** Use `z` (zoxide): after visiting a
  directory once, `z proj`, `z ess`, `z dot` jump straight there by a fragment of
  the path. `zi` gives an interactive picker when several match.
- **Fuzzy-jump when you don't remember the name:** `fcd` (both shells) or `Alt-C`
  (zsh) opens an fzf picker of subdirectories with a tree preview.
- **Stay in one terminal with tmux.** One session per project; `prefix |` / `prefix -`
  to split. `Ctrl-h/j/k/l` moves seamlessly between tmux panes *and* Neovim splits.
  Detach with `prefix d`, reattach later with `tmux a` — your layout survives.
- **`cd -` toggles** between the last two directories.

## Searching

A two-step rhythm beats scrolling: **filter to candidates, then act.**

- **Content search:** `rg "pattern"` — fast, respects `.gitignore`. Scope by type
  (`rg -t rust TODO`), show context (`-C3`), list files only (`-l`).
- **Filename search:** `fd name` — skips `.git` and ignored files by default.
- **History:** `Ctrl-R` (atuin) — fuzzy, deduped, synced. Type any fragment of a
  command you ran days ago. Far better than arrow-up spamming.
- **Find-then-edit in one move:** `ff` lists files through fzf with a bat preview
  and opens your pick in Neovim. For content, do it inside the editor:
  `nvim` then `<leader>/` greps the whole project and jumps you to the hit.
- **Pipe into fzf** whenever a command spits a long list:
  `git branch | fzf`, `brew leaves | fzf`, `rg -l TODO | fzf`.

## Editing

- **Neovim is the editor everywhere** — `$EDITOR`, `$GIT_EDITOR`, `$KUBE_EDITOR`,
  and `fc` all open it. Learn it once, use it for commit messages, `kubectl edit`,
  rebases, everything.
- **Inside Neovim (LazyVim):** `<leader>ff` to open files, `<leader>/` to grep,
  `gd`/`gr` to navigate code, `K` for docs, `<leader>ca` for fixes, `<leader>cr` to
  rename across the project, `<leader>cf` to format. `:checkhealth` if something's off.
- **Don't reformat blindly on commit.** The pre-commit hook *checks* formatting
  (it won't rewrite your partial staging). If it complains, run the fixer it names
  (`gofmt -w`, `cargo fmt`, `<pm> run format`) and re-stage.

## Git

- **Branch, don't commit to `main`.** `git switch -c feat/ROG-1234-thing`. Direct
  commits to protected branches are blocked by the hook.
- **Write traceable messages:** include the ticket key — `ROG-1234: fix token
  refresh`. The commit-msg hook enforces it; the body is free-form.
- **Use lazygit (`lg`) for the messy parts** — stage individual hunks, amend,
  reorder, resolve conflicts visually. `git lg` (alias) shows a graph log.
- **Diffs are rendered by delta** automatically — side-by-side, syntax-highlighted.
- **Pushing runs lint + fast tests** for the repo's languages. If you genuinely need
  to skip: `HOOKS_SKIP_TESTS=1 git push`, or `git push --no-verify` for everything.
- **Force-pushing to a protected branch is blocked** — a safety net before CI.

## Secrets

- **Never paste a secret into a tracked file.** The pre-commit secret scan
  (gitleaks → regex fallback) will block it.
- **To version a secret,** encrypt it: `dots secret-add ~/.ssh/id_ed25519`
  stores ciphertext (`encrypted_*.age`) that's safe in a public repo. It only
  decrypts on machines that hold `~/.config/chezmoi/key.txt` — back that key up.

## Keeping the machine current

- **One command:** `dots update` — pulls config changes and upgrades brew,
  rust, swift, uv/python, Neovim plugins, and Doom.
- **Change configs the chezmoi way:** `chezmoi edit ~/.config/nvim/init.lua` →
  `chezmoi apply`. To preview, `chezmoi diff`. Never hand-edit a managed file in
  place — your next `apply` would revert it.
- **Capture a machine-local tweak** back into the repo with `chezmoi re-add`, then
  commit & push so every machine gets it.

## A few muscle-memory combos

```sh
z api && ff                  # jump to a project, fuzzy-open a file in nvim
rg -l "TODO" | fzf | xargs nvim   # pick among files containing TODO, edit it
git switch -c fix/ROG-22-null && lg   # branch, then stage+commit in lazygit
chezmoi edit ~/.zshrc && chezmoi apply  # tweak a dotfile and apply it
```
