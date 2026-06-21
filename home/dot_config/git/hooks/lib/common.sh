#!/usr/bin/env bash
# Shared helpers for the global git hooks. Sourced by every hook.
# Pure bash (3.2+ compatible). No `set -e` here — hooks manage exit codes.

# ---------------------------------------------------------------------------
# Defaults. Override globally in ~/.config/git/hooks.conf, or per-repo with
# `git config hooks.<key> <value>`, or per-invocation with the env vars noted
# in each hook. git-config always wins over these defaults.
# ---------------------------------------------------------------------------
: "${HOOKS_PROTECTED_BRANCHES:=main master develop release/* hotfix/*}"
: "${HOOKS_TICKET_PATTERN:=[A-Z][A-Z0-9]+-[0-9]+}"
: "${HOOKS_SUBJECT_MAX_LEN:=72}"
: "${HOOKS_MAX_FILE_SIZE_MB:=5}"

# Load user config (may override the above).
_hooks_conf="${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks.conf"
# shellcheck source=/dev/null
[ -f "$_hooks_conf" ] && . "$_hooks_conf"

# ---------------------------------------------------------------------------
# Config accessors: git config `hooks.<key>` overrides the given fallback.
# ---------------------------------------------------------------------------
cfg() { # cfg <key> <fallback>
  local v
  v=$(git config --get "hooks.$1" 2>/dev/null || true)
  if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "${2-}"; fi
}
_truthy() {
  case "$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}
cfg_bool() { _truthy "$(cfg "$1" "$2")"; } # cfg_bool <key> <fallback-bool>

# ---------------------------------------------------------------------------
# Output (color only on a TTY).
# ---------------------------------------------------------------------------
if [ -t 2 ]; then
  _RED=$'\033[31m'; _YLW=$'\033[33m'; _GRN=$'\033[32m'; _CYN=$'\033[36m'; _DIM=$'\033[2m'; _RST=$'\033[0m'
else
  _RED=; _YLW=; _GRN=; _CYN=; _DIM=; _RST=
fi
_HOOK_TAG="${_HOOK_TAG:-git-hooks}"
hook_info() { printf '%s» [%s] %s%s\n' "$_DIM" "$_HOOK_TAG" "$*" "$_RST" >&2; }
hook_ok()   { printf '%s✓ %s%s\n' "$_GRN" "$*" "$_RST" >&2; }
hook_warn() { printf '%s⚠ %s%s\n' "$_YLW" "$*" "$_RST" >&2; }
hook_err()  { printf '%s✗ %s%s\n' "$_RED" "$*" "$_RST" >&2; }
hook_hint() { printf '  %s%s%s\n' "$_DIM" "$*" "$_RST" >&2; }
hook_step() { printf '%s→ %s%s\n' "$_CYN" "$*" "$_RST" >&2; }

# ---------------------------------------------------------------------------
# Global enable/disable.
# ---------------------------------------------------------------------------
hooks_disabled() { [ "${HOOKS_DISABLE:-}" = 1 ] || cfg_bool disable false; }

# ---------------------------------------------------------------------------
# Git state helpers.
# ---------------------------------------------------------------------------
have()           { command -v "$1" >/dev/null 2>&1; }
repo_root()      { git rev-parse --show-toplevel 2>/dev/null; }
git_dir()        { git rev-parse --git-dir 2>/dev/null; }
current_branch() { git symbolic-ref --quiet --short HEAD 2>/dev/null || true; }
in_worktree()    { [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; }
has_head()       { git rev-parse --verify --quiet HEAD >/dev/null 2>&1; }

rebase_in_progress() { local g; g=$(git_dir) || return 1; [ -d "$g/rebase-merge" ] || [ -d "$g/rebase-apply" ]; }
merge_in_progress()  { local g; g=$(git_dir) || return 1; [ -f "$g/MERGE_HEAD" ]; }
cherry_in_progress() { local g; g=$(git_dir) || return 1; [ -f "$g/CHERRY_PICK_HEAD" ]; }

# True when the SHA is the all-zeros sentinel (ref create/delete), any length.
is_zero_sha() { case "$1" in *[!0]*) return 1 ;; '') return 1 ;; *) return 0 ;; esac; }

# Branch matches a protected pattern (glob patterns allowed, e.g. release/*).
is_protected() { # is_protected <branch>
  local b="$1" pat
  [ -n "$b" ] || return 1
  for pat in $(cfg protectedBranches "$HOOKS_PROTECTED_BRANCHES" | tr ',' ' '); do
    # shellcheck disable=SC2254  # intentional glob match
    case "$b" in $pat) return 0 ;; esac
  done
  return 1
}

# Staged files (NUL-separated), added/copied/modified/renamed only.
staged_files_z() { git diff --cached --name-only --diff-filter=ACMR -z; }

# ---------------------------------------------------------------------------
# Language detection.
#   detect_langs  : whole-repo, by root marker files (for tests/lint/deps)
#   staged_langs  : by staged file extensions (for fmt on touched files)
# Both echo a newline list from {go,rust,swift,node,python,jvm}.
# ---------------------------------------------------------------------------
detect_langs() {
  local root out=""
  root=$(repo_root) || return 0
  [ -f "$root/go.mod" ] && out="$out go"
  [ -f "$root/Cargo.toml" ] && out="$out rust"
  [ -f "$root/Package.swift" ] && out="$out swift"
  [ -f "$root/package.json" ] && out="$out node"
  { [ -f "$root/pyproject.toml" ] || [ -f "$root/requirements.txt" ] || [ -f "$root/setup.py" ] || [ -f "$root/setup.cfg" ]; } && out="$out python"
  { [ -f "$root/build.gradle" ] || [ -f "$root/build.gradle.kts" ] || [ -f "$root/settings.gradle" ] || [ -f "$root/settings.gradle.kts" ] || [ -f "$root/pom.xml" ]; } && out="$out jvm"
  printf '%s' "$out" | tr ' ' '\n' | sed '/^$/d' | sort -u
}

staged_langs() {
  local f out=""
  while IFS= read -r -d '' f; do
    case "$f" in
      *.go) out="$out go" ;;
      *.rs) out="$out rust" ;;
      *.swift) out="$out swift" ;;
      *.js | *.jsx | *.ts | *.tsx | *.mjs | *.cjs) out="$out node" ;;
      *.py) out="$out python" ;;
      *.kt | *.kts | *.java) out="$out jvm" ;;
    esac
  done < <(staged_files_z)
  printf '%s' "$out" | tr ' ' '\n' | sed '/^$/d' | sort -u
}

# Staged files for a language extension set (NUL-sep), echoed space-joined+quoted-safe.
staged_files_matching() { # staged_files_matching <glob...>
  local f g match
  while IFS= read -r -d '' f; do
    match=0
    for g in "$@"; do
      # shellcheck disable=SC2254
      case "$f" in $g) match=1; break ;; esac
    done
    [ "$match" = 1 ] && printf '%s\n' "$f"
  done < <(staged_files_z)
}

# ---------------------------------------------------------------------------
# Node package-manager + script detection.
# ---------------------------------------------------------------------------
node_pm() {
  local root; root=$(repo_root)
  if   [ -f "$root/bun.lockb" ] && have bun;        then echo bun
  elif [ -f "$root/pnpm-lock.yaml" ] && have pnpm;  then echo pnpm
  elif [ -f "$root/yarn.lock" ] && have yarn;       then echo yarn
  elif have npm;                                    then echo npm
  else echo ""; fi
}
has_npm_script() { # has_npm_script <name>
  local root; root=$(repo_root)
  [ -f "$root/package.json" ] || return 1
  if have jq; then
    jq -e --arg s "$1" '.scripts[$s] // empty' "$root/package.json" >/dev/null 2>&1
  else
    grep -Eq "\"$1\"[[:space:]]*:" "$root/package.json"
  fi
}

# ---------------------------------------------------------------------------
# Secret scanning: gitleaks if present, else a built-in regex fallback.
# Scans only staged additions. Honors `allowlist secret` pragmas.
# ---------------------------------------------------------------------------
scan_secrets() {
  cfg_bool secretScan true || return 0
  if have gitleaks; then
    hook_step "secret scan (gitleaks)"
    if gitleaks protect --staged --redact --no-banner >&2 2>/dev/null; then
      return 0
    else
      hook_err "gitleaks flagged potential secrets in staged changes"
      hook_hint "remove them, or allowlist: add to .gitleaksignore / append '# gitleaks:allow'"
      return 1
    fi
  fi

  hook_step "secret scan (built-in patterns; install gitleaks for full coverage)"
  local added findings
  added=$(git diff --cached -U0 --no-color --diff-filter=ACM 2>/dev/null \
    | grep -E '^\+' | grep -Ev '^\+\+\+' \
    | grep -Eiv 'allowlist secret|gitleaks:allow|pragma: ?allowlist')
  [ -z "$added" ] && return 0

  findings=$(printf '%s\n' "$added" | grep -Ein \
    -e 'AKIA[0-9A-Z]{16}' \
    -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
    -e '(ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{30,}' \
    -e 'xox[baprs]-[0-9A-Za-z-]{10,}' \
    -e 'AIza[0-9A-Za-z_\-]{35}' \
    -e 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' )
  # Generic key=secret assignments (case-insensitive).
  findings="$findings
$(printf '%s\n' "$added" | grep -Eni '(secret|password|passwd|api[_-]?key|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}["'\'']')"
  findings=$(printf '%s\n' "$findings" | sed '/^[[:space:]]*$/d')

  if [ -n "$findings" ]; then
    hook_err "potential secrets in staged changes:"
    printf '%s\n' "$findings" | sed 's/^/    /' >&2
    hook_hint "remove them, or annotate the line with '# gitleaks:allow' / 'allowlist secret'"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Large-file guard (checks staged blob sizes).
# ---------------------------------------------------------------------------
check_large_files() {
  cfg_bool checkLargeFiles true || return 0
  local mb max f size bad=0
  mb=$(cfg maxFileSizeMB "$HOOKS_MAX_FILE_SIZE_MB")
  max=$((mb * 1024 * 1024))
  while IFS= read -r -d '' f; do
    size=$(git cat-file -s ":$f" 2>/dev/null) || continue
    if [ "${size:-0}" -gt "$max" ]; then
      hook_err "large file staged: $f ($((size / 1024 / 1024)) MiB > ${mb} MiB)"
      bad=1
    fi
  done < <(git diff --cached --name-only --diff-filter=ACM -z)
  if [ "$bad" = 1 ]; then
    hook_hint "track with Git LFS (git lfs track '<pattern>') or unstage it"
    hook_hint "override: git config hooks.checkLargeFiles false  (or raise hooks.maxFileSizeMB)"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Chain to a repo-local hook (.git/hooks/<name>) and to husky (.husky/<name>),
# so projects that manage their own hooks keep working under a global hooksPath.
# ---------------------------------------------------------------------------
run_local_hook() { # run_local_hook <name> [args...]
  local name="$1"; shift
  local gd lh root rc=0
  gd=$(git_dir) || return 0
  lh="$gd/hooks/$name"
  if [ -x "$lh" ] && [ "$lh" != "$0" ]; then
    hook_info "delegating to repo hook: .git/hooks/$name"
    "$lh" "$@" || rc=$?
    [ "$rc" -ne 0 ] && return "$rc"
  fi
  root=$(repo_root 2>/dev/null) || return 0
  if [ -n "$root" ] && [ -x "$root/.husky/$name" ]; then
    hook_info "delegating to .husky/$name"
    "$root/.husky/$name" "$@" || rc=$?
    [ "$rc" -ne 0 ] && return "$rc"
  fi
  return 0
}
