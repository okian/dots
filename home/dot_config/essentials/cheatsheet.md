# essentials — cheatsheet

Quick reference for the aliases, commands, and keybindings this setup ships.
View anytime with `essentials cheatsheet` (nushell) or `cheatsheet` (zsh).

> Shells: **nushell** is your default (vi edit mode); **zsh** is the fallback.
> Most things below work in both; differences are noted.

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
| `docker` | `podman` | + `dc`/`docker-compose` → `podman-compose` |

## Functions / commands

| Command | What it does |
|---------|--------------|
| `ff` | fuzzy-find a file (bat preview) → open in Neovim |
| `fcd` | fuzzy-find a directory → cd into it |
| `z <dir>` | jump to a frecent directory (zoxide); `zi` = interactive |
| `essentials update` | upgrade configs + all toolchains to latest |
| `essentials tip` / `tips` | random / all usage tips |
| `essentials cheatsheet` | open this file |
| `essentials hooks status` | global git-hooks state; `enable`/`disable`/`test` |
| `essentials secret-add <p>` | encrypt a file & stage it into the repo |

## Shell keybindings

| Key | Action | Where |
|-----|--------|-------|
| `Ctrl-R` | fuzzy, synced history search (atuin) | both |
| `Ctrl-T` | insert a file path (fzf + bat preview) | zsh (use `ff` in nushell) |
| `Alt-C` | cd into a subdirectory (fzf) | zsh (use `fcd` in nushell) |
| `Esc` then `k`/`j`/`/` | vi-mode: normal mode, search history | both |
| `→` / `Ctrl-F` | accept autosuggestion | zsh |

## Neovim / LazyVim (leader = `Space`)

| Key | Action |
|-----|--------|
| `<leader>ff` | find files | 
| `<leader>/` | grep across the project |
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

## tmux (prefix = `Ctrl-a`)

| Key | Action |
|-----|--------|
| `prefix` `|` / `-` | split vertical / horizontal |
| `Ctrl-h/j/k/l` | move between panes *and* nvim splits (vim-tmux-navigator) |
| `prefix` `r` | reload config |
| `prefix` `[` | copy mode (`v` select, `y` yank, vi keys) |
| `prefix` `c` / `n` / `1-9` | new window / next / select |
| `prefix` `z` | zoom pane |

## WezTerm

Standard macOS shortcuts: `⌘T` new tab, `⌘W` close, `⌘1–9` switch tab,
`⌘+`/`⌘-` font size, `⌘C`/`⌘V` copy/paste. Use **tmux** for splits/panes.

## CLI tools at a glance

| Need | Tool | Example |
|------|------|---------|
| find files by name | `fd` | `fd config` |
| search file contents | `rg` (ripgrep) | `rg "func main" -t go` |
| fuzzy filter anything | `fzf` | `... | fzf` |
| view a file | `bat` | `bat src/main.rs` |
| list / tree | `eza` | `eza --tree` |
| jump dirs | `zoxide` | `z proj` |
| JSON / YAML | `jq` / `yq` | `cat x.json | jq .` |
| git TUI | `lazygit` | `lg` |
| diffs | `delta` | (auto, via git; `n`/`N` navigates hunks) |
| structural diff | `difftastic` | `git dft` |
| auto-fixup commits | `git-absorb` | `git absorb` |
| containers | `podman` | `docker run ...` (aliased) |
| secrets | `chezmoi` + `age` | `essentials secret-add <f>` |
| example-first help | `tldr` (tealdeer) | `tldr ffmpeg` |
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
