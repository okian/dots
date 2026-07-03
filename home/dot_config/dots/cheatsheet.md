# dots — cheatsheet

Quick reference for the aliases, commands, and keybindings this setup ships.
View anytime with `dots cheatsheet`.

> Shells: **nushell** is your default (vi edit mode); **zsh** is a lean
> fallback (shared env, theme and aliases — the `tv` helpers live only in nu).

## Managing this setup — one command

`dots` wraps chezmoi + git so you never call them directly. Run bare
`dots` for the full menu. Mental model: **edit → diff → apply** locally;
**pull ↓ / save ↑** with the remote.

| Command | What it does |
|---------|--------------|
| `dots edit <file>` | edit a managed file, then apply it |
| `dots diff` | preview pending changes to your home dir |
| `dots apply` | apply your local edits |
| `dots add <p>` | start managing a file (`--encrypt` for secrets) |
| `dots readd [p]` | capture machine-local edits to managed files back into the repo |
| `dots show <file>` | show a file's fully rendered content |
| `dots pull` | get latest from the remote and apply (↓) |
| `dots save [msg]` | stage everything, commit & push (↑) |
| `dots status` | uncommitted changes + pending apply |
| `dots update` | pull + apply + upgrade **every** toolchain |
| `dots upgrade` | upgrade toolchains only (no pull/apply) |
| `dots packages` | edit packages.yaml; auto-applies (installers re-run) if changed |
| `dots autoupdate` | background 4-hourly CLI upgrades (macOS): `enable`/`disable`/`status`/`log` |
| `dots cd` | jump into the dotfiles source dir |
| `dots managed` / `doctor` / `log` | list managed files / diagnose / history |

## Color themes — one command, everywhere

`dots theme` retints WezTerm, Neovim, Doom Emacs, nushell, television, lazygit,
bat and starship together. Built-in: **catppuccin-mocha**, **nord**,
**tokyo-night**, **gruvbox-dark**.

| Command | What it does |
|---------|--------------|
| `dots theme` | fuzzy-pick a theme |
| `dots theme list` | list themes (● = active) |
| `dots theme set nord` | switch everything to Nord |

WezTerm and a running Emacs daemon retint **instantly**; starship updates
next prompt; new nushell/Neovim pick it up (`exec nu` to retint the current
shell, `:colorscheme <name>` for a running nvim). The choice lives in
`~/.config/dots/` and survives `dots pull`/`update`.

## Aliases

| Alias | Runs | Notes |
|-------|------|-------|
| `ls` | `eza --icons --group-directories-first` | icons + dirs first |
| `ll` | `eza -la` | long, all, with icons |
| `la` | `ls -a` | all entries |
| `lt` | `eza --tree --level=2` | 2-level tree |
| `cat` | `bat` | syntax highlight + paging |
| `g` | `git` | |
| `lg` | `lazygit` | visual git TUI |
| `v`, `vim` | `nvim` | |
| `dc` | `docker compose` | docker CLI talks to the colima runtime natively |

## Functions / commands

| Command | What it does |
|---------|--------------|
| `ff` | fuzzy-find a file (bat preview) → open in Neovim |
| `fcd` | fuzzy-find a directory → cd into it |
| `fsym` | fuzzy-search code symbols (classes/funcs/vars, ctags) → open at line |
| `proj` | fuzzy-pick a git repo under ~/projects → cd in (Ctrl-S: its symbols) |
| `mkcd <dir>` | make a directory (and parents) then cd into it |
| `extract <file>` | extract any archive by extension (tar/gz/zip/7z/rar…) |
| `ports` | listening TCP ports + the owning process |
| `killp` | fuzzy-pick a running process and kill it |
| `gcap "msg"` | git add -A → commit → push, in one shot |
| `y` | open yazi; cd's to wherever you quit it — inside, `z`/`Z` fuzzy-jump via tv |
| `z <dir>` | jump to a frecent directory (zoxide); `zi` = interactive picker (tv) |
| `dots update` | upgrade configs + all toolchains to latest |
| `dots tip` / `tips` | random / all usage tips |
| `dots cheatsheet` | open this file |
| `dots hooks status` | global git-hooks state; `enable`/`disable`/`test` |
| `dots secret-add <p>` | encrypt a file & stage it into the repo |
| `dots git-identity …` | per-entity git identities (see below) |

## Per-entity git identities (`~/projects/<entity>/`)

Each top-level directory under `~/projects` is an **entity** (work, personal, NGO…)
with its own git name/email/signing key. Any repo cloned under
`~/projects/cuju/` automatically commits as your *cuju* identity; anything outside
`~/projects` uses the global identity.

| Command | What it does |
|---------|--------------|
| `dots git-identity add <entity> <email> [name]` | create the identity, make `~/projects/<entity>/`, then **encrypt + commit + push** |
| `dots git-identity edit <entity>` | edit in `$EDITOR`; if changed, **re-encrypt + commit + push** |
| `dots git-identity list` | show each entity's resolved name/email + whether its dir exists |
| `dots git-identity sync` | regenerate the `includeIf` blocks from `~/projects` |

`add`/`edit` are fully automated — one command writes the identity, encrypts it
into the repo, asserts the ciphertext leaks no plaintext (aborts otherwise),
commits only that `.age` file, and pushes. Pass `--no-push` to stop before push.

How it wires up (no manual editing needed):
- `~/.config/git/config` ends with `[include] conf.d/identities.gitconfig`.
- `~/bins/git-identities-sync` regenerates that file on **every** `chezmoi apply`
  with one `[includeIf "gitdir:~/projects/<entity>/"]` per entity dir.
- Per-entity files live at `~/.config/git/conf.d/<entity>.gitconfig`, persisted
  encrypted as `conf.d/encrypted_<entity>.gitconfig.age` in the repo.
- On a fresh machine with no `~/projects`, the entities you've encrypted are
  recreated as directories automatically (`chezmoi update`).

## Shell keybindings

| Key | Action | Where |
|-----|--------|-------|
| `Ctrl-R` | fuzzy history search (television) — filters as you type, Enter to run | both |
| `Ctrl-T` | smart autocomplete for the current command (television) | both |
| `ff` / `fcd` | fuzzy-find a file to edit / dir to cd (television) | nu |
| `fsym` / `proj` | fuzzy-search code symbols / pick a repo under ~/projects (television) | nu |
| `tv` | open the fuzzy finder; `tv text` greps, `tv symbols` jumps to code symbols, `tv tldr` browses cheatsheets | both |
| `Esc` then `k`/`j`/`/` | vi-mode: normal mode, search history | both |
| `→` | accept the autosuggestion (`Ctrl-→` accepts one word) | both |

## Neovim / LazyVim (leader = `Space`)

| Key | Action |
|-----|--------|
| `<leader>ff` | find files (snacks.picker) | 
| `<leader>/` | grep across the project |
| `<leader>fv` / `<leader>sv` | television: find files / grep text (same `tv` UI as the shell) |
| `<leader>fb` | switch buffer |
| `<leader>e` | toggle file explorer (neo-tree) |
| `<leader>gg` | open lazygit |
| `gd` / `gr` | go to definition / references |
| `K` | hover docs |
| `<leader>ca` / `<leader>cr` | code action / rename |
| `<leader>cf` | format buffer |
| `<leader>l` | Lazy plugin manager |
| `:LazyExtras` | add language/tool support (toggle a row, restart) |
| `<leader>bd` | close buffer |
| `Space` (wait) | **which-key** menu — discover every binding, no memorizing |
| `:checkhealth` | diagnose your setup |

## WezTerm (leader = `Ctrl-Space`)

The terminal multiplexer — native splits/panes/tabs, no tmux. Follows
`dots theme`; bottom tab bar shows `index · process · cwd`, right status shows
leader/workspace/battery/clock.

| Key | Action |
|-----|--------|
| `leader` `\` / `-` | split horizontal / vertical |
| `Ctrl-h/j/k/l` | move between panes *and* nvim splits (seamless) |
| `leader` `H/J/K/L` | resize the active pane |
| `leader` `z` / `x` | zoom / close pane |
| `leader` `c` / `n` / `p` / `1-9` | new tab / next / prev / jump |
| `leader` `[` | copy mode |
| `leader` `f` | quick-select (grab a URL/path/hash on screen) |
| `leader` `Space` | command palette |
| `leader` `w` | workspace switcher |
| `⌘/Ctrl +`/`-`/`0` | font size up / down / reset |
| `⌘/Ctrl Enter` | toggle fullscreen |
| `⌘`-drag | move the window (no title bar) |

The unfocused pane dims automatically. `Ctrl-h/j/k/l` crosses the Neovim↔WezTerm
boundary transparently (smart-splits.nvim).

## macOS — Hammerspoon (keyboard-layout fixer)

Typed a whole phrase in the wrong layout (meant فارسی, got `sghl`; or meant
English, got Persian glyphs)? Select it and hit the hotkey — it detects the
script and re-maps each key positionally to the other layout, pasting the
fix over your selection (your clipboard is preserved).

| Key | Action |
|-----|--------|
| `⌘⌥K` | fix the selected text's keyboard layout (EN ⇄ FA) |

Config lives in `~/.hammerspoon/init.lua` (managed). **First run only:** enable
Hammerspoon under System Settings → Privacy & Security → Accessibility, and turn
on "Launch Hammerspoon at login". macOS-only.

## CLI tools at a glance

| Need | Tool | Example |
|------|------|---------|
| find files by name | `fd` | `fd config` |
| search file contents | `rg` (ripgrep) | `rg "func main" -t go` |
| fuzzy filter anything | `tv` (television) | `... | tv` |
| view a file | `bat` | `bat src/main.rs` |
| list / tree | `eza` | `eza --tree` |
| jump dirs | `zoxide` | `z proj` |
| JSON / YAML | `jq` / `yq` | `cat x.json | jq .` |
| git TUI | `lazygit` | `lg` |
| diffs | `delta` | (auto, via git; `n`/`N` navigates hunks) |
| structural diff | `difftastic` | `git dft` |
| auto-fixup commits | `git-absorb` | `git absorb` |
| containers | `colima` + `docker` | `colima start`, then `docker run ...` |
| secrets | `chezmoi` + `age` | `dots secret-add <f>` |
| example-first help | `tldr` (tealdeer) | `tldr ffmpeg` |
| jump to a code symbol | `tv symbols` / `fsym` | classes/funcs/vars via ctags |
| browse cheatsheets fuzzily | `tv tldr` | pick a page, preview rendered |
| task runner | `just` | `just` lists recipes; `just build` |
| file manager | `yazi` | `y` (cd's to where you quit) |
| system monitor | `btop` | `btop` (also `top`) |
| disk usage / free | `dust` / `duf` | `dust`, `duf` |
| processes | `procs` | `procs node` |
| find & replace | `sd` | `sd 'foo' 'bar' file` |
| HTTP client | `xh` | `xh GET httpbin.org/json` |
| JSON explorer | `jless` | `jless < big.json` |
| benchmarking | `hyperfine` | `hyperfine 'cmd a' 'cmd b'` |
| kubernetes TUI | `k9s` | `k9s` |
| image/repo scan | `trivy` | `trivy fs .` |
| image layers | `dive` | `dive <image>` |
| media metadata | `exiftool` | `exiftool clip.mov` |
| download video | `yt-dlp` | `yt-dlp <url>` |

See `workflows.md` (next to this file) for how to combine these efficiently.
