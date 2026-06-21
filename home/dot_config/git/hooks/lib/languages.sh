#!/usr/bin/env bash
# Per-language checks for the global git hooks. Sourced after common.sh.
# Each function: returns 0 on pass/skip, 1 on failure, and explains itself.
# Missing tools degrade to a skip (with a note) rather than a hard failure.

_skip() { hook_info "$1 (skipped: $2)"; return 0; }

# ===========================================================================
# FORMAT CHECK (pre-commit) — scoped to staged files where practical.
# ===========================================================================
lang_format_check() { # lang_format_check <lang>
  case "$1" in
    go)     _fmt_go ;;
    rust)   _fmt_rust ;;
    swift)  _fmt_swift ;;
    node)   _fmt_node ;;
    python) _fmt_python ;;
    jvm)    _fmt_jvm ;;
    *) return 0 ;;
  esac
}

_fmt_go() {
  have gofmt || return 0
  local files bad
  files=$(staged_files_matching '*.go')
  [ -z "$files" ] && return 0
  hook_step "go: gofmt"
  # shellcheck disable=SC2086
  bad=$(gofmt -l $files 2>/dev/null)
  if [ -n "$bad" ]; then
    hook_err "go files need formatting:"; printf '%s\n' "$bad" | sed 's/^/    /' >&2
    hook_hint "fix: gofmt -w <files>  (or: go fmt ./...)"
    return 1
  fi
}

_fmt_rust() {
  have cargo || return 0
  [ -f "$(repo_root)/Cargo.toml" ] || return 0
  [ -n "$(staged_files_matching '*.rs')" ] || return 0
  hook_step "rust: cargo fmt --check"
  if ! ( cd "$(repo_root)" && cargo fmt --all --check ) >&2 2>&1; then
    hook_err "rust files need formatting"
    hook_hint "fix: cargo fmt --all"
    return 1
  fi
}

_fmt_swift() {
  local files; files=$(staged_files_matching '*.swift'); [ -z "$files" ] && return 0
  if have swiftformat; then
    hook_step "swift: swiftformat --lint"
    # shellcheck disable=SC2086
    if ! swiftformat --lint $files >&2 2>&1; then
      hook_err "swift files need formatting"; hook_hint "fix: swiftformat <files>"; return 1
    fi
  elif have swift-format; then
    hook_step "swift: swift-format lint"
    # shellcheck disable=SC2086
    if ! swift-format lint --strict $files >&2 2>&1; then
      hook_err "swift files need formatting"; hook_hint "fix: swift-format format -i <files>"; return 1
    fi
  else
    _skip "swift format" "no swiftformat/swift-format"
  fi
}

_fmt_node() {
  local files; files=$(staged_files_matching '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' '*.cjs' '*.json' '*.css' '*.md')
  [ -z "$files" ] && return 0
  if has_npm_script "format:check"; then
    hook_step "node: $(node_pm) run format:check"
    ( cd "$(repo_root)" && $(node_pm) run --silent format:check ) >&2 2>&1 || {
      hook_err "prettier/format check failed"; hook_hint "fix: $(node_pm) run format"; return 1; }
  elif have npx; then
    hook_step "node: prettier --check"
    # --no-install: only runs if prettier is a project dep; otherwise no-op skip.
    # shellcheck disable=SC2086
    if ( cd "$(repo_root)" && npx --no-install prettier --check $files ) >&2 2>&1; then
      return 0
    else
      local rc=$?
      # npx exits 1 when prettier isn't installed too; treat "not found" as skip.
      if ( cd "$(repo_root)" && npx --no-install prettier --version ) >/dev/null 2>&1; then
        hook_err "prettier check failed"; hook_hint "fix: npx prettier --write <files>"; return 1
      fi
      _skip "node format" "prettier not a project dependency"
      return 0
    fi
  else
    _skip "node format" "no npx"
  fi
}

_fmt_python() {
  have ruff || return 0
  local files; files=$(staged_files_matching '*.py'); [ -z "$files" ] && return 0
  hook_step "python: ruff format --check"
  # shellcheck disable=SC2086
  if ! ruff format --check $files >&2 2>&1; then
    hook_err "python files need formatting"; hook_hint "fix: ruff format <files>"; return 1
  fi
}

_fmt_jvm() {
  have ktlint || return 0
  local files; files=$(staged_files_matching '*.kt' '*.kts'); [ -z "$files" ] && return 0
  hook_step "kotlin: ktlint"
  # shellcheck disable=SC2086
  if ! ktlint $files >&2 2>&1; then
    hook_err "kotlin files have lint/format issues"; hook_hint "fix: ktlint --format <files>"; return 1
  fi
}

# ===========================================================================
# LINT (pre-push) — whole project, the heavier pass.
# ===========================================================================
lang_lint() { # lang_lint <lang>
  case "$1" in
    go)     _lint_go ;;
    rust)   _lint_rust ;;
    swift)  _lint_swift ;;
    node)   _lint_node ;;
    python) _lint_python ;;
    jvm)    return 0 ;;  # gradle/detekt too slow for a push gate; reminder only
    *) return 0 ;;
  esac
}

_lint_go() {
  have go || return 0
  local rc=0
  if have golangci-lint; then
    hook_step "go: golangci-lint run"
    ( cd "$(repo_root)" && golangci-lint run ) >&2 2>&1 || rc=1
  else
    hook_step "go: go vet ./..."
    ( cd "$(repo_root)" && go vet ./... ) >&2 2>&1 || rc=1
  fi
  if [ "$rc" -ne 0 ]; then hook_err "go lint failed"; return 1; fi
  return 0
}

_lint_rust() {
  have cargo || return 0
  hook_step "rust: cargo clippy -D warnings"
  if ! ( cd "$(repo_root)" && cargo clippy --all-targets --all-features -- -D warnings ) >&2 2>&1; then
    hook_err "clippy failed"; return 1
  fi
}

_lint_swift() {
  have swiftlint || return 0
  hook_step "swift: swiftlint"
  if ! ( cd "$(repo_root)" && swiftlint --quiet ) >&2 2>&1; then
    hook_err "swiftlint failed"; return 1
  fi
}

_lint_node() {
  has_npm_script lint || return 0
  hook_step "node: $(node_pm) run lint"
  if ! ( cd "$(repo_root)" && $(node_pm) run --silent lint ) >&2 2>&1; then
    hook_err "node lint failed"; return 1
  fi
}

_lint_python() {
  have ruff || return 0
  hook_step "python: ruff check"
  if ! ( cd "$(repo_root)" && ruff check . ) >&2 2>&1; then
    hook_err "ruff check failed"; return 1
  fi
}

# ===========================================================================
# TEST (pre-push) — the "fast part" of the suite.
# ===========================================================================
lang_test() { # lang_test <lang>
  case "$1" in
    go)     _test_go ;;
    rust)   _test_rust ;;
    swift)  _test_swift ;;
    node)   _test_node ;;
    python) _test_python ;;
    jvm)    return 0 ;;  # too slow for a push gate by default
    *) return 0 ;;
  esac
}

_test_go() {
  have go || return 0
  hook_step "go: go test -short ./..."
  ( cd "$(repo_root)" && go test -short ./... ) >&2 2>&1 || { hook_err "go tests failed"; return 1; }
}
_test_rust() {
  have cargo || return 0
  hook_step "rust: cargo test"
  ( cd "$(repo_root)" && cargo test --all ) >&2 2>&1 || { hook_err "cargo test failed"; return 1; }
}
_test_swift() {
  have swift || return 0
  [ -f "$(repo_root)/Package.swift" ] || return 0
  hook_step "swift: swift test"
  ( cd "$(repo_root)" && swift test ) >&2 2>&1 || { hook_err "swift test failed"; return 1; }
}
_test_node() {
  has_npm_script test || return 0
  local pm; pm=$(node_pm); [ -z "$pm" ] && return 0
  hook_step "node: $pm test"
  ( cd "$(repo_root)" && CI=true $pm test --silent ) >&2 2>&1 || { hook_err "node tests failed"; return 1; }
}
_test_python() {
  local runner=""
  if have pytest; then runner="pytest -q"
  elif have python3 && python3 -c 'import pytest' >/dev/null 2>&1; then runner="python3 -m pytest -q"
  else return 0; fi
  hook_step "python: $runner"
  ( cd "$(repo_root)" && eval "$runner" ) >&2 2>&1 || { hook_err "pytest failed"; return 1; }
}

# ===========================================================================
# DEPENDENCY REMINDERS (post-checkout / post-merge).
# Given two refs, print a hint per changed manifest; optionally auto-install.
# ===========================================================================
deps_reminder() { # deps_reminder <refA> <refB>
  local a="$1" b="$2" changed auto
  changed=$(git diff --name-only "$a" "$b" 2>/dev/null) || return 0
  [ -z "$changed" ] && return 0
  cfg_bool autoInstallDeps false && auto=1 || auto=0
  local root; root=$(repo_root)

  _dep() { # _dep <regex> <label> <install-cmd>
    printf '%s\n' "$changed" | grep -Eq "$1" || return 0
    if [ "$auto" = 1 ]; then
      hook_step "deps: $2 changed — running: $3"
      ( cd "$root" && eval "$3" ) >&2 2>&1 || hook_warn "auto-install failed for $2 (run manually: $3)"
    else
      hook_warn "$2 changed — you may need to: $3"
    fi
  }

  _dep '(^|/)go\.(mod|sum)$'                         "go modules"     "go mod download"
  _dep '(^|/)Cargo\.(toml|lock)$'                    "cargo deps"     "cargo fetch"
  _dep '(^|/)Package\.(swift|resolved)$'             "swift packages" "swift package resolve"
  _dep '(^|/)(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb)$' \
       "node deps" "$(node_pm) install"
  _dep '(^|/)(pyproject\.toml|poetry\.lock|requirements.*\.txt|uv\.lock)$' \
       "python deps" "$( [ -f "$root/uv.lock" ] && echo 'uv sync' || echo 'pip install -r requirements.txt' )"
  _dep '(^|/)(build\.gradle(\.kts)?|settings\.gradle(\.kts)?|gradle/libs\.versions\.toml|pom\.xml)$' \
       "JVM build files" "./gradlew --refresh-dependencies  (or reimport in your IDE)"
}
