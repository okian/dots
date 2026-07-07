# config.nu — managed by chezmoi.

# Theme registry + the `dots theme` switcher. Defs/consts only — nothing from
# it RUNS until the theme block at the bottom of this file.
source ~/.config/dots/themes.nu

# Aliases and commands come FIRST, the theme/appearance block LAST: appearance
# depends on generated files under ~/.config/dots/ and must never be able to
# cost a shell its commands (in nushell an error mid-config aborts the rest).

# Aliases. eza is aliased unconditionally (it's guaranteed by packages.yaml):
# nu block-scopes aliases inside `if`, so the old `which eza` guard silently
# dropped ls/lt on every machine.
alias ls = eza --icons --group-directories-first
alias lt = eza --tree --level=2 --icons
alias ll = ls -la
alias la = ls -a
alias g = git
alias lg = lazygit
alias c = claude
alias v = nvim
alias vim = nvim
alias cat = bat
alias top = btop
# Containers: docker CLI talks to colima natively; short alias for compose.
alias dc = docker compose

# Fuzzy-find a file (television's `files` channel: bat preview built in) and
# open it in the editor.
def ff [] {
  let file = (^tv files | str trim)
  if ($file | is-not-empty) { ^$env.EDITOR $file }
}

# Fuzzy-find a directory and cd into it (fd feeds television via stdin; tree
# preview from the `dirs` channel definition shipped in config).
def --env fcd [] {
  let dir = (^fd --type d --hidden --follow --exclude .git
    | ^tv --preview-command 'eza --tree --level=2 --color=always {}' | str trim)
  if ($dir | is-not-empty) { cd $dir }
}

# Fuzzy-search code symbols (classes/funcs/vars) in the current project and jump
# to one (television's `symbols` channel: universal-ctags index, bat preview
# scrolled to the line, Enter opens it in the editor). Terminal counterpart to
# Neovim's LSP symbol search.
def fsym [] { ^tv symbols }

# Pick a git project under ~/projects and cd into it (television's `projects`
# channel; Ctrl-S inside jumps to that repo's symbols, Ctrl-E edits).
def --env proj [] {
  let dir = (^tv projects | str trim)
  if ($dir | is-not-empty) { cd $dir }
}

# `y` opens yazi and cd's to wherever you quit it. Hardened over the official
# wrapper: `try` around yazi so the temp file is always cleaned up, and the
# path is trimmed before the comparison.
def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXX")
  try { ^yazi ...$args --cwd-file $tmp }
  let cwd = (open $tmp | str trim)
  rm -fp $tmp
  if $cwd != "" and $cwd != $env.PWD { cd $cwd }
}

# Make a directory (and parents) then cd into it.
def --env mkcd [dir: string] {
  mkdir $dir
  cd $dir
}

# Extract almost any archive by extension — no need to remember the flags.
def extract [file: path] {
  if not ($file | path exists) {
    error make { msg: $"no such file: ($file)" }
    return
  }
  let name = ($file | str lowercase)
  if ($name | str ends-with ".tar.gz") or ($name | str ends-with ".tgz") {
    ^tar xzf $file
  } else if ($name | str ends-with ".tar.bz2") {
    ^tar xjf $file
  } else if ($name | str ends-with ".tar.xz") {
    ^tar xJf $file
  } else if ($name | str ends-with ".tar") {
    ^tar xf $file
  } else if ($name | str ends-with ".gz") {
    ^gunzip $file
  } else if ($name | str ends-with ".zip") {
    ^unzip $file
  } else if ($name | str ends-with ".7z") or ($name | str ends-with ".rar") {
    ^7zz x $file
  } else {
    error make { msg: $"don't know how to extract ($file)" }
  }
}

# Listening TCP ports with the owning process (macOS + Linux via lsof).
def ports [] {
  ^lsof -nP -iTCP -sTCP:LISTEN
  | lines | skip 1
  | parse --regex '^(?<process>\S+)\s+(?<pid>\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(?<address>.+?)\s+\(LISTEN\)'
  | uniq-by address
  | sort-by address
}

# Fuzzy-pick a running process and kill it (television reads the list on stdin).
def killp [] {
  let pid = (ps | each { |p| $"($p.pid)\t($p.name)" }
    | str join (char nl)
    | ^tv | split row "\t" | first | str trim)
  if ($pid | is-not-empty) { kill ($pid | into int) }
}

# git add-commit-push in one shot: `gcap "message"`.
def gcap [message: string] {
  git add -A
  git commit -m $message
  git push
}

# --- Email from the terminal (Apple Mail; macOS only) ------------------------
# `mail`  — you write it:   ls | mail kian@example.com -s "the listing"
#                           mail kian@example.com "on my way" -s "eta"
# `fmail` — the on-device model (`fm`, macOS 27) writes subject + body from
#           whatever context you pipe/pass; opens a DRAFT for review by default.

# Normalize a comma-separated address list: trim spaces and <angle brackets>.
def _mail_addrs [s: string] {
  $s | split row ','
    | each {|a| $a | str trim | str trim --char '<' | str trim --char '>' | str trim }
    | where {|a| $a | is-not-empty }
    | str join ','
}

# Body/context resolution: piped input wins (tables render like the terminal
# shows them); otherwise the trailing word arguments.
def _mail_text [piped: any, words: list<string>] {
  if ($piped | is-empty) {
    $words | str join ' '
  } else if (($piped | describe) == 'string') {
    $piped
  } else {
    $piped | table --expand | ansi strip
  }
}

# Compose in Mail.app via AppleScript. action: "send" | "draft". Values travel
# as argv (never spliced into the script), so quoting in subjects/bodies is safe.
def _mail_deliver [to: string, cc: string, bcc: string, from: string, subject: string, body: string, action: string] {
  if ($nu.os-info.name != 'macos') {
    error make --unspanned { msg: "mail/fmail drive Apple Mail — macOS only." }
  }
  let script = '
on run argv
  set {theTo, theCc, theBcc, theFrom, theSubject, theBody, theAction} to argv
  tell application "Mail"
    set msg to make new outgoing message with properties {subject:theSubject, content:theBody, visible:(theAction is "draft")}
    tell msg
      repeat with a in my splitAddrs(theTo)
        make new to recipient at end of to recipients with properties {address:(contents of a)}
      end repeat
      repeat with a in my splitAddrs(theCc)
        make new cc recipient at end of cc recipients with properties {address:(contents of a)}
      end repeat
      repeat with a in my splitAddrs(theBcc)
        make new bcc recipient at end of bcc recipients with properties {address:(contents of a)}
      end repeat
    end tell
    if theFrom is not "" then set sender of msg to theFrom
    if theAction is "send" then
      send msg
    else
      activate
    end if
  end tell
end run

on splitAddrs(s)
  if s is "" then return {}
  set text item delimiters to ","
  set parts to text items of s
  set text item delimiters to ""
  return parts
end splitAddrs
'
  ^osascript -e $script (_mail_addrs $to) (_mail_addrs $cc) (_mail_addrs $bcc) ($from | str trim) $subject $body $action
}

# Send an email with Apple Mail. Body from the pipe, or as trailing words.
# --from picks the sending account (default: Mail's default account);
# --draft opens the message in Mail for review instead of sending.
def mail [
  to: string                 # recipient(s), comma-separated
  ...body: string            # body text (ignored when input is piped)
  --subject (-s): string = ""
  --cc: string = ""
  --bcc: string = ""
  --from: string = ""        # sending address (must match a Mail account)
  --draft (-d)               # review in Mail instead of sending straight away
] {
  let text = (_mail_text $in $body)
  if ($text | str trim | is-empty) and ($subject | is-empty) {
    print "usage: <pipe> | mail <to> -s <subject>   or   mail <to> <body...> -s <subject>"
    return
  }
  let action = (if $draft { "draft" } else { "send" })
  _mail_deliver $to $cc $bcc $from $subject $text $action
  if $draft { print "==> draft opened in Mail." } else { print $"==> sent to ($to)." }
}

# Like `mail`, but Apple's on-device model writes the subject and body FROM the
# piped/argument context. Drafts by default — review AI text before it leaves
# the machine; pass --send to trust it and ship immediately.
#   git log -5 | fmail team@example.com
#   fmail a@b.com "ask about the delayed shipment, friendly tone" --send
def fmail [
  to: string                 # recipient(s), comma-separated
  ...context: string         # what the mail should say (ignored when piped)
  --cc: string = ""
  --bcc: string = ""
  --from: string = ""        # sending address (must match a Mail account)
  --send                     # send immediately instead of opening the draft
] {
  let ctx = (_mail_text $in $context)
  if ($ctx | str trim | is-empty) {
    print "usage: <pipe> | fmail <to>   or   fmail <to> <what to say...>"
    return
  }
  if (which fm | is-empty) {
    error make --unspanned { msg: "fm (Apple Foundation Models CLI, macOS 27) not found — use `mail` instead." }
  }
  let msg = (_fmail_parse (_fm_generate $ctx) $ctx)
  let action = (if $send { "send" } else { "draft" })
  _mail_deliver $to $cc $bcc $from $msg.subject $msg.body $action
  if $send {
    print $"==> sent to ($to): ($msg.subject)"
  } else {
    print $"==> draft opened in Mail: ($msg.subject)"
  }
}

# Compose the email with the on-device model (fm CLI, macOS 27). `fm schema`
# pins the output shape, so the reply is guaranteed {subject, body} JSON.
def _fm_generate [context: string] {
  let schema = (mktemp -t "fmail-schema.XXXXX")
  ^fm schema object --name Email --string subject --string body | save -f $schema
  let r = ($context | ^fm respond --no-stream --schema $schema --instructions "You draft emails. From the context given, write a concise, friendly email: a short subject and a plain-text body ready to send." | complete)
  rm -f $schema
  if $r.exit_code != 0 or ($r.stdout | str trim | is-empty) {
    error make --unspanned { msg: $"fm failed: ($r.stderr | str trim)" }
  }
  $r.stdout | str trim
}

# Model output -> {subject, body}; falls back to the raw text when not JSON.
def _fmail_parse [raw: string, ctx: string] {
  let cleaned = ($raw | str replace --all '```json' '' | str replace --all '```' '' | str trim)
  let parsed = (try { $cleaned | from json } catch { null })
  if $parsed != null and (($parsed | describe) | str starts-with 'record') and ('subject' in $parsed) and ('body' in $parsed) {
    { subject: ($parsed.subject | into string), body: ($parsed.body | into string) }
  } else {
    { subject: ($ctx | lines | first | str substring 0..60), body: $cleaned }
  }
}

# starship / zoxide / carapace / television (tv) are auto-sourced from the vendor
# autoload dir populated by env.nu — no manual `source` needed here. tv binds
# Ctrl-T (smart autocomplete) and Ctrl-R (history).

# `dots` commands (update, secrets, hooks, tips, cheatsheet).
source ~/.config/nushell/dots.nu

# --- Theme & shell appearance (kept LAST on purpose) --------------------------
# Reads generated, NOT-chezmoi-managed files (~/.config/dots/*). Try-guarded and
# ordered after everything above, so a stale/corrupt theme artifact — or a
# surprise from a background-auto-upgraded tool — degrades to the default
# colors instead of killing every alias and command in this file.
let theme = (try { _theme_active } catch { $THEME_REGISTRY | get $THEME_DEFAULT })
let pal = $theme.palette

$env.config = {
  show_banner: false
  edit_mode: vi
  cursor_shape: { vi_insert: line, vi_normal: block }
  completions: { case_sensitive: false, quick: true, partial: true, algorithm: "fuzzy" }
  history: { max_size: 100_000, file_format: "sqlite" }

  # Table/value colors, derived from the active theme palette.
  color_config: (color_config_from_palette $pal)

  # Completion menu, themed to match. (History search is television's Ctrl-R.)
  menus: [
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "│ "
      type: { layout: columnar columns: 4 col_padding: 2 }
      style: {
        text: $pal.fg
        selected_text: { fg: $pal.bg bg: $pal.accent }
        description_text: $pal.subtle
      }
    }
  ]
  keybindings: [
    { name: completion_menu modifier: none keycode: tab mode: [vi_insert vi_normal]
      event: { until: [ { send: menu name: completion_menu } { send: menunext } ] } }
    # Gray history autosuggestion (shown automatically, colored `hints` in the
    # palette): → accepts the whole thing (reedline default); Ctrl-Y here too;
    # Ctrl-→ accepts just the next word (fish-style partial accept).
    { name: accept_suggestion modifier: control keycode: char_y mode: [vi_insert]
      event: { send: historyhintcomplete } }
    { name: accept_suggestion_word modifier: control keycode: right mode: [vi_insert vi_normal]
      event: { send: historyhintwordcomplete } }
  ]

  hooks: {
    # direnv: load per-project env on each prompt (no-op if direnv absent).
    pre_prompt: [{ ||
      try {
        if (which direnv | is-not-empty) {
          direnv export json | from json | default {} | load-env
        }
      }
    }]
  }
}

# Theme-driven environment: bat theme and the active starship config (a
# palette-swapped copy of starship.toml written by `dots theme`). Television's
# colours follow the theme via a generated theme file, not an env var.
$env.BAT_THEME = $theme.bat
let _ss_cfg = ($nu.home-dir | path join '.config' 'dots' 'starship.toml')
if ($_ss_cfg | path exists) { $env.STARSHIP_CONFIG = $_ss_cfg }

# Random usage tip on interactive startup only (opt out with $env.DOTS_NO_TIPS).
# Guarded by is-interactive so `nu -c ...` scripts stay clean.
if $nu.is-interactive and ('DOTS_NO_TIPS' not-in $env) { dots tip }
