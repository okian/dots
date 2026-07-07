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
#                           mail "Kian Ostad" "on my way" -s "eta"
# `fmail` — the on-device model (`fm`, macOS 27) writes subject + body from
#           whatever context you pipe/pass; opens a DRAFT for review by default.
# Recipients (to/cc/bcc) may be an email OR a Contacts name — a bare name (no @)
# is resolved via macOS Contacts (first use prompts once for Contacts access).
# Attach files with -a and a LIST (nushell can't repeat a flag): -a [a.pdf b.png].

# Resolve a person's name to an email via macOS Contacts. Returns the email of
# the single best match; errors (never guesses) if there's no match or it's
# ambiguous. First use prompts once for Contacts access (System Settings →
# Privacy & Security → Contacts).
def _contact_email [name: string] {
  let script = '
on run argv
  set q to item 1 of argv
  set out to ""
  tell application "Contacts"
    repeat with p in (people whose name contains q)
      if (count of emails of p) > 0 then
        set out to out & (name of p) & tab & (value of first email of p) & linefeed
      end if
    end repeat
  end tell
  return out
end run
'
  let rows = (^osascript -e $script $name
    | lines | where {|l| ($l | str trim) != "" }
    | each {|l| let p = ($l | split row (char tab)); { name: ($p | first), email: ($p | last) } })
  if ($rows | is-empty) {
    error make --unspanned { msg: $"no Contacts entry with an email matches \"($name)\"" }
  }
  # Rank matches so the best wins without prompting: exact full name (0) > a name
  # word that starts with the query, e.g. 'hani' -> 'Haniyeh' (1) > plain
  # substring (2). Only ambiguity *within* the best tier is an error.
  let q = ($name | str lowercase | str trim)
  let ranked = ($rows
    | insert rank {|r|
        let n = ($r.name | str lowercase)
        if $n == $q { 0 } else if ($n | split row ' ' | any {|w| $w | str starts-with $q }) { 1 } else { 2 }
      }
    | sort-by rank
    | uniq-by email)
  let best = ($ranked | where rank == ($ranked | first | get rank))
  if ($best | length) > 1 {
    error make --unspanned { msg: $"\"($name)\" matches several contacts \(($best | get name | str join ', ')\) — use a fuller name or the email address." }
  }
  $best | first | get email
}

# Normalize a comma-separated recipient list: trim spaces and <angle brackets>,
# and resolve any bare name (no @) against Contacts.
def _mail_addrs [s: string] {
  $s | split row ','
    | each {|a| $a | str trim | str trim --char '<' | str trim --char '>' | str trim }
    | where {|a| $a | is-not-empty }
    | each {|a| if ($a | str contains '@') { $a } else { _contact_email $a } }
    | str join ','
}

# Render piped input to text: strings pass through; structured data renders the
# way the terminal shows it. Empty pipe -> "".
def _mail_render [piped: any] {
  if ($piped | is-empty) {
    ""
  } else if (($piped | describe) == 'string') {
    $piped
  } else {
    $piped | table --expand | ansi strip
  }
}

# `mail` body resolution. The word args are the body; piped input is the
# content. When BOTH are given, the words come first, then a newline, then the
# pipe — so `ls | mail x "here are the files:"` reads as the line then the list.
# Either one alone is used as-is.
def _mail_text [piped: any, words: list<string>] {
  let rendered = (_mail_render $piped)
  let w = ($words | str join ' ')
  if ($w | is-empty) {
    $rendered
  } else if ($rendered | str trim | is-empty) {
    $w
  } else {
    $w + "\n" + $rendered
  }
}

# Compose in Mail.app via AppleScript. action: "send" | "draft". Values travel
# as argv (never spliced into the script), so quoting in subjects/bodies is safe.
# to/cc/bcc arrive already resolved (names → emails) and comma-joined by the
# caller. Attachments follow the 7 fixed args as extra argv items (absolute paths).
def _mail_deliver [to: string, cc: string, bcc: string, from: string, subject: string, body: string, action: string, attachments: list<string>] {
  if ($nu.os-info.name != 'macos') {
    error make --unspanned { msg: "mail/fmail drive Apple Mail — macOS only." }
  }
  let script = '
on run argv
  set theTo to item 1 of argv
  set theCc to item 2 of argv
  set theBcc to item 3 of argv
  set theFrom to item 4 of argv
  set theSubject to item 5 of argv
  set theBody to item 6 of argv
  set theAction to item 7 of argv
  set theAttachments to {}
  if (count of argv) > 7 then set theAttachments to items 8 thru -1 of argv
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
      repeat with a in theAttachments
        make new attachment with properties {file name:(POSIX file (contents of a))} at after the last paragraph of content
      end repeat
    end tell
    if theFrom is not "" then set sender of msg to theFrom
    if theAction is "send" then
      -- let Mail finish encoding attachments before it fires the message off
      if (count of theAttachments) > 0 then delay 1
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
  ^osascript -e $script $to $cc $bcc ($from | str trim) $subject $body $action ...$attachments
}

# Expand + validate attachment paths (relative to the current dir or ~). Errors
# (listing every missing file) before Mail opens, not after. The check is hoisted
# out of the map so the message isn't swallowed by `each`'s wrapper error.
def _mail_attachments [files: list<string>] {
  let expanded = ($files | each {|f| $f | path expand })
  let missing = ($expanded | where {|p| not ($p | path exists) })
  if ($missing | is-not-empty) {
    error make --unspanned { msg: $"attachment not found: ($missing | str join ', ')" }
  }
  $expanded
}

# Send an email with Apple Mail. Body = the word args and/or piped input; when
# both are given, the words go first and the pipe follows on the next line.
# --attach takes a LIST of files (nushell can't repeat a flag): -a [a.pdf b.png].
# --from picks the sending account (default: Mail's default account);
# --draft opens the message in Mail for review instead of sending.
def mail [
  to: string                 # recipient(s): email or Contacts name, comma-separated
  ...body: string            # body text (combined with any piped input)
  --subject (-s): string = ""
  --cc: string = ""
  --bcc: string = ""
  --from: string = ""        # sending address (must match a Mail account)
  --attach (-a): list<string> = []   # file(s) to attach:  -a [report.pdf logo.png]
  --draft (-d)               # review in Mail instead of sending straight away
] {
  let text = (_mail_text $in $body)
  if ($text | str trim | is-empty) and ($subject | is-empty) and ($attach | is-empty) {
    print "usage: <pipe> | mail <to> -s <subject>   or   mail <to> <body...> -s <subject> [-a [file …]]"
    return
  }
  # Resolve recipient names → emails and validate attachments first, so a bad
  # name or missing file fails before anything is sent.
  let to_r = (_mail_addrs $to)
  let cc_r = (_mail_addrs $cc)
  let bcc_r = (_mail_addrs $bcc)
  let files = (_mail_attachments $attach)
  let action = (if $draft { "draft" } else { "send" })
  _mail_deliver $to_r $cc_r $bcc_r $from $subject $text $action $files
  if $draft { print $"==> draft opened in Mail for ($to_r)." } else { print $"==> sent to ($to_r)." }
}

# Like `mail`, but a model writes the subject and body. The word args say what
# the mail is FOR (the intent/framing); anything piped in is the MATERIAL to
# base it on — both are used together. Model routing: short input stays on the
# on-device model (fast, offline, private); longer input (more than a few lines)
# goes to the cloud — Apple's Private Cloud Compute, and if that's unavailable,
# the Claude CLI. Opens a draft by default so you review before it leaves;
# --send ships immediately.
#   git log -15 | fmail c@okian.eu "here are my last dotfiles commits"
#   fmail "Kian Ostad" "ask about the delayed shipment, friendly tone" --send
def fmail [
  to: string                 # recipient(s): email or Contacts name, comma-separated
  ...context: string         # what the mail is for (used together with any pipe)
  --cc: string = ""
  --bcc: string = ""
  --from: string = ""        # sending address (must match a Mail account)
  --attach (-a): list<string> = []   # file(s) to attach:  -a [report.pdf logo.png]
  --send                     # send immediately instead of opening the draft
] {
  let words = ($context | str join ' ' | str trim)
  let raw_material = (_mail_render $in)
  if ($words | is-empty) and ($raw_material | str trim | is-empty) {
    print "usage: <pipe> | fmail <to> [what it's for]   or   fmail <to> <what to say...>"
    return
  }
  # Resolve recipient names → emails and validate attachments FIRST, so a bad
  # name or missing file fails before we spend time composing.
  let to_r = (_mail_addrs $to)
  let cc_r = (_mail_addrs $cc)
  let bcc_r = (_mail_addrs $bcc)
  let files = (_mail_attachments $attach)
  let have_fm = (which fm | is-not-empty)
  let have_claude = (which claude | is-not-empty)
  if (not $have_fm) and (not $have_claude) {
    error make --unspanned { msg: "no model available — need `fm` (macOS 27) or the `claude` CLI." }
  }
  # Route by size: a few lines stay on-device; more (by line OR char count, so a
  # single long blob also counts) goes to the cloud.
  let nonempty = ($raw_material | lines | where {|l| ($l | str trim) != "" } | length)
  let long = ($nonempty > 6) or (($raw_material | str length) > 800)
  let raw = (if (not $long) and $have_fm {
      # Short: on-device. Trim (usually a no-op here) so it always fits.
      let material = (_fm_fit $raw_material 2800)
      if ($material != ($raw_material | str trim)) {
        print $"(ansi yellow)note(ansi reset) input trimmed to fit the on-device model."
      }
      _fm_respond (_fmail_prompt $words $material) "system"
    } else {
      # Long (or no on-device model): cloud. Try Apple's private cloud, then Claude.
      let prompt = (_fmail_prompt $words $raw_material)
      let pcc = (if $have_fm {
          try { { ok: true, text: (_fm_respond $prompt "pcc") } } catch {|e| { ok: false, err: $e.msg } }
        } else { { ok: false, err: "fm not installed" } })
      if $pcc.ok {
        $pcc.text
      } else if $have_claude {
        print $"(ansi yellow)note(ansi reset) Apple cloud unavailable — composing with Claude."
        _claude_respond $prompt
      } else {
        error make --unspanned { msg: $"cloud compose failed: ($pcc.err)" }
      }
    })
  let msg = (_fmail_parse $raw (_fmail_prompt $words $raw_material))
  let action = (if $send { "send" } else { "draft" })
  _mail_deliver $to_r $cc_r $bcc_r $from $msg.subject $msg.body $action $files
  if $send {
    print $"==> sent to ($to_r): ($msg.subject)"
  } else {
    print $"==> draft opened in Mail for ($to_r): ($msg.subject)"
  }
}

# Trim material to a token budget the on-device model can hold (its context is
# ~4k tokens; leave room for the instructions and the generated reply). Cheap
# length gate first, then `fm token-count`; truncates by proportional character
# length and marks the cut. Never grows short input.
def _fm_fit [material: string, budget: int] {
  let m = ($material | str trim)
  if ($m | str length) < ($budget * 2) { return $m }
  let toks = (try { $m | ^fm token-count | into int } catch { 0 })
  if $toks == 0 or $toks <= $budget { return $m }
  let keep = ($m | str length) * $budget / $toks * 9 / 10 | into int
  ($m | str substring 0..$keep | str trim) + "\n\n…[truncated to fit the on-device model]"
}

# Build the model prompt: the word args are the goal/intent, the piped data is
# the material to ground the email in. Either or both may be present.
def _fmail_prompt [words: string, material: string] {
  let w = ($words | str trim)
  let m = ($material | str trim)
  if ($w | is-not-empty) and ($m | is-not-empty) {
    $"Write an email that accomplishes this:\n($w)\n\nBase it on this material — summarize it, do not copy it verbatim:\n($m)"
  } else if ($w | is-not-empty) {
    $"Write an email that accomplishes this:\n($w)"
  } else {
    $"Write an email that presents and summarizes the following:\n($m)"
  }
}

# Instructions shared by every compose backend. Keep the email GROUNDED: base it
# only on what's given, summarize (don't transcribe), and never invent a sender,
# greeting, signature, or sign-off (an ungrounded model happily makes up a "Dots
# Team" and a "Hi <name>" — we forbid that). One rule per line so the small
# on-device model can track them.
def _fmail_instructions [] {
  ([
    "You are the user's email-writing assistant. Turn the request into a ready-to-send email: a specific subject line and a plain-text body. Rules:"
    "- Write in the first person, as the sender. Use the tone the request asks for; otherwise keep it neutral and professional."
    "- Ground every statement in the request and material provided. Never invent facts, names, numbers, dates, links, recipients, or events that are not given."
    "- If the material is a list or log, summarize it in your own words — do not copy it verbatim, and never reproduce long tokens like commit hashes, IDs, or timestamps."
    "- Make the subject specific and informative — never generic like 'Update' or 'Hello'."
    "- The body is plain text only: no Markdown, asterisks, backticks, or headings."
    "- Do not fabricate an identity: never invent or guess the sender's or recipient's name, a team, company, or product; never use a placeholder like '[Your Name]'; and add no signature or sign-off. Prefer no greeting — if the tone calls for one, keep it generic ('Hi,') and never guess a name."
    "- Be concise — no longer than the content needs; skip filler pleasantries."
  ] | str join (char nl))
}

# Compose via the fm CLI on <model> ("system" on-device | "pcc" Apple's private
# cloud). `fm schema` pins the reply to {subject, body} JSON.
def _fm_respond [prompt: string, model: string] {
  let schema = (mktemp -t "fmail-schema.XXXXX")
  ^fm schema object --name Email --string subject --string body | save -f $schema
  let r = ($prompt | ^fm respond --model $model --no-stream --schema $schema --instructions (_fmail_instructions) | complete)
  rm -f $schema
  if $r.exit_code != 0 or ($r.stdout | str trim | is-empty) {
    error make --unspanned { msg: $"fm \(($model)\) failed: ($r.stderr | str trim)" }
  }
  $r.stdout | str trim
}

# Compose via the Claude CLI (headless cloud fallback). Same instructions; asks
# for the {subject, body} JSON that _fmail_parse expects.
def _claude_respond [prompt: string] {
  let full = ([
    (_fmail_instructions)
    'Output ONLY a JSON object with two keys, "subject" and "body" (both plain-text strings). No prose, no code fences.'
    ""
    $prompt
  ] | str join "\n")
  let r = ($full | ^claude -p | complete)
  if $r.exit_code != 0 or ($r.stdout | str trim | is-empty) {
    error make --unspanned { msg: $"claude failed: ($r.stderr | str trim)" }
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
