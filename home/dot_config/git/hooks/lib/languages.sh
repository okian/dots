#!/usr/bin/env bash
# Per-language checks for the global git hooks. Sourced after common.sh.
# Each function: returns 0 on pass/skip, 1 on failure, and explains itself.
# Missing tools degrade to a skip (with a note) rather than a hard failure.

_skip() { hook_info "$1 (skipped: $2)"; return 0; }

# ===========================================================================
# STAGED FAST PASS (pre-commit) — format + fast per-file lint, scoped to staged
# files where practical. Heavier whole-repo linters live in the LINT pass below.
# ===========================================================================
lang_format_check() { # lang_format_check <lang>
  case "$1" in
    go)        _fmt_go ;;
    rust)      _fmt_rust ;;
    swift)     _fmt_swift ;;
    node)      _fmt_node ;;
    python)    _fmt_python ;;
    jvm)       _fmt_jvm ;;
    shell)     _fmt_shell ;;
    docker)    _fmt_docker ;;
    terraform) _fmt_terraform ;;
    *) return 0 ;;
  esac
}

_fmt_go() {
  local files bad tool
  files=$(staged_files_matching '*.go')
  [ -z "$files" ] && return 0
  # Prefer the strictest formatter installed: gofumpt ⊃ gofmt; goimports also
  # fixes import grouping. All three support -l (list files needing formatting).
  if   have gofumpt;   then tool=gofumpt
  elif have goimports; then tool=goimports
  elif have gofmt;     then tool=gofmt
  else return 0
  fi
  hook_step "go: $tool -l"
  # shellcheck disable=SC2086
  bad=$($tool -l $files 2>/dev/null)
  if [ -n "$bad" ]; then
    hook_err "go files need formatting:"; printf '%s\n' "$bad" | sed 's/^/    /' >&2
    hook_hint "fix: $tool -w <files>  (or: go fmt ./...)"
    return 1
  fi
}

_fmt_rust() {
  have cargo || return 0
  [ -f "$(repo_root)/Cargo.toml" ] || return 0
  [ -n "$(staged_files_matching '*.rs')" ] || return 0
  hook_step "rust: cargo fmt --check"
  if ! run_at_root cargo fmt --all --check; then
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
    run_at_root "$(node_pm)" run --silent format:check || {
      hook_err "prettier/format check failed"; hook_hint "fix: $(node_pm) run format"; return 1; }
  elif have npx; then
    hook_step "node: prettier --check"
    # --no-install: only runs if prettier is a project dep; otherwise no-op skip.
    # shellcheck disable=SC2086
    if run_at_root npx --no-install prettier --check $files; then
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

_fmt_shell() {
  local files; files=$(staged_files_matching '*.sh' '*.bash'); [ -z "$files" ] && return 0
  local rc=0
  if have shellcheck; then
    local sev; sev=$(cfg shellcheckSeverity warning)
    hook_step "shell: shellcheck --severity=$sev"
    # shellcheck disable=SC2086
    run_at_root shellcheck --severity="$sev" -- $files || { hook_err "shellcheck found issues"; rc=1; }
  fi
  # shfmt is opinionated about style, so it's opt-in (git config hooks.shfmt true).
  if have shfmt && cfg_bool shfmt false; then
    hook_step "shell: shfmt -d"
    # shellcheck disable=SC2086
    if ! shfmt -d $files >&2 2>&1; then
      hook_err "shell files need formatting"; hook_hint "fix: shfmt -w <files>"; rc=1
    fi
  fi
  return $rc
}

_fmt_docker() {
  have hadolint || return 0
  local files
  files=$(staged_files_matching 'Dockerfile' '*/Dockerfile' '*.Dockerfile' 'Dockerfile.*' '*/Dockerfile.*' 'Containerfile' '*/Containerfile')
  [ -z "$files" ] && return 0
  hook_step "docker: hadolint"
  # shellcheck disable=SC2086
  if ! run_at_root hadolint $files; then
    hook_err "hadolint found Dockerfile issues"
    hook_hint "fix them, or inline-ignore a rule: # hadolint ignore=DLxxxx"
    return 1
  fi
}

_fmt_terraform() {
  local files; files=$(staged_files_matching '*.tf' '*.tfvars'); [ -z "$files" ] && return 0
  local tool
  if   have tofu;      then tool=tofu
  elif have terraform; then tool=terraform
  else return 0
  fi
  hook_step "terraform: $tool fmt -check"
  # `fmt` targets a directory; check each dir that has staged HCL (dedup inline).
  local f d seen="" rc=0
  while IFS= read -r f; do
    d=$(dirname "$f")
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"
    run_at_root "$tool" fmt -check -diff "$d" || rc=1
  done < <(printf '%s\n' "$files")
  if [ "$rc" -ne 0 ]; then
    hook_err "terraform files need formatting"; hook_hint "fix: $tool fmt"
    return 1
  fi
  return 0
}

# ===========================================================================
# LINT (pre-push) — whole project, the heavier pass.
# ===========================================================================
lang_lint() { # lang_lint <lang>
  case "$1" in
    go)        _lint_go ;;
    rust)      _lint_rust ;;
    swift)     _lint_swift ;;
    node)      _lint_node ;;
    python)    _lint_python ;;
    terraform) _lint_terraform ;;
    k8s)       _lint_k8s ;;
    jvm)    return 0 ;;  # gradle/detekt too slow for a push gate; reminder only
    *) return 0 ;;
  esac
}

_lint_go() {
  have go || return 0
  local rc=0
  # Prefer golangci-lint (bundles staticcheck & more); else standalone
  # staticcheck; else the built-in go vet.
  if have golangci-lint; then
    # Fall back to the shipped conservative config when the repo has none;
    # a repo-local .golangci.* always wins (then $def is empty → run bare).
    local def cfg_arg=""
    def=$(default_lint_config golangci.yml .golangci.yml .golangci.yaml .golangci.toml .golangci.json)
    [ -n "$def" ] && cfg_arg="--config $def"
    hook_step "go: golangci-lint run${cfg_arg:+ (dots default config)}"
    # shellcheck disable=SC2086
    run_at_root golangci-lint run $cfg_arg || rc=1
  elif have staticcheck; then
    hook_step "go: staticcheck ./..."
    run_at_root staticcheck ./... || rc=1
  else
    hook_step "go: go vet ./..."
    run_at_root go vet ./... || rc=1
  fi
  # go.mod/go.sum tidiness — non-mutating check (needs Go 1.23+ for `-diff`).
  if cfg_bool goModTidy true && [ -f "$(repo_root)/go.mod" ] \
     && go help mod tidy 2>/dev/null | grep -q -- '-diff'; then
    hook_step "go: go mod tidy -diff"
    if ! run_at_root go mod tidy -diff; then
      hook_err "go.mod/go.sum not tidy"; hook_hint "fix: go mod tidy"; rc=1
    fi
  fi
  if [ "$rc" -ne 0 ]; then hook_err "go lint failed"; return 1; fi
  return 0
}

_lint_rust() {
  have cargo || return 0
  hook_step "rust: cargo clippy -D warnings"
  if ! run_at_root cargo clippy --all-targets --all-features -- -D warnings; then
    hook_err "clippy failed"; return 1
  fi
}

_lint_swift() {
  have swiftlint || return 0
  hook_step "swift: swiftlint"
  if ! run_at_root swiftlint --quiet; then
    hook_err "swiftlint failed"; return 1
  fi
}

_lint_node() {
  has_npm_script lint || return 0
  hook_step "node: $(node_pm) run lint"
  if ! run_at_root "$(node_pm)" run --silent lint; then
    hook_err "node lint failed"; return 1
  fi
}

_lint_python() {
  have ruff || return 0
  # Shipped default unless the repo brings its own ruff config. ruff.toml /
  # .ruff.toml is handled by the helper; a [tool.ruff] table in pyproject.toml
  # counts as local too, so void the default in that case.
  local def cfg_arg="" root
  def=$(default_lint_config ruff.toml ruff.toml .ruff.toml)
  root=$(repo_root)
  if [ -n "$def" ] && [ -f "$root/pyproject.toml" ] && grep -q '^\[tool\.ruff' "$root/pyproject.toml"; then
    def=""
  fi
  [ -n "$def" ] && cfg_arg="--config $def"
  hook_step "python: ruff check${cfg_arg:+ (dots default config)}"
  # shellcheck disable=SC2086
  if ! run_at_root ruff check $cfg_arg .; then
    hook_err "ruff check failed"; return 1
  fi
}

_lint_terraform() {
  local rc=0
  if have tflint; then
    hook_step "terraform: tflint --recursive"
    run_at_root tflint --recursive || { hook_err "tflint failed"; rc=1; }
  fi
  if cfg_bool tfSecurity true && have trivy; then
    hook_step "terraform: trivy config"
    run_at_root trivy config --exit-code 1 --quiet . || { hook_err "trivy found misconfigurations"; rc=1; }
  fi
  # terraform-docs README freshness — opt-in (mutating-adjacent), needs a README.
  if cfg_bool tfDocs false && have terraform-docs; then
    hook_step "terraform: terraform-docs (check)"
    run_at_root terraform-docs md . --output-file README.md --output-check \
      || { hook_err "terraform-docs README is stale"; hook_hint "fix: terraform-docs md . --output-file README.md --output-mode inject"; rc=1; }
  fi
  return $rc
}

_lint_k8s() {
  local rc=0 root chart; root=$(repo_root)
  # helm lint per chart dir (a dir with a Chart.yaml).
  if have helm; then
    while IFS= read -r chart; do
      [ -n "$chart" ] || continue
      hook_step "k8s: helm lint $(dirname "$chart")"
      run_at_root helm lint "$(dirname "$chart")" || { hook_err "helm lint failed"; rc=1; }
    done < <(find "$root" \( -name .git -o -name node_modules \) -prune -o -name Chart.yaml -print 2>/dev/null)
  fi
  # Policy-as-code — opt-in; needs a repo-root policy/ dir of rego.
  if cfg_bool k8sPolicy false && have conftest && [ -d "$root/policy" ]; then
    hook_step "k8s: conftest test ."
    run_at_root conftest test . || { hook_err "conftest policy check failed"; rc=1; }
  fi
  return $rc
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
  run_at_root go test -short ./... || { hook_err "go tests failed"; return 1; }
}
_test_rust() {
  have cargo || return 0
  hook_step "rust: cargo test"
  run_at_root cargo test --all || { hook_err "cargo test failed"; return 1; }
}
_test_swift() {
  have swift || return 0
  [ -f "$(repo_root)/Package.swift" ] || return 0
  hook_step "swift: swift test"
  run_at_root swift test || { hook_err "swift test failed"; return 1; }
}
_test_node() {
  has_npm_script test || return 0
  local pm; pm=$(node_pm); [ -z "$pm" ] && return 0
  hook_step "node: $pm test"
  run_at_root env CI=true "$pm" test --silent || { hook_err "node tests failed"; return 1; }
}
_test_python() {
  local runner=""
  if have pytest; then runner="pytest -q"
  elif have python3 && python3 -c 'import pytest' >/dev/null 2>&1; then runner="python3 -m pytest -q"
  else return 0; fi
  hook_step "python: $runner"
  run_at_root eval "$runner" || { hook_err "pytest failed"; return 1; }
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
  # Pick the install command that matches the project's actual python tooling.
  local py_install
  if   [ -f "$root/uv.lock" ];          then py_install='uv sync'
  elif [ -f "$root/poetry.lock" ];      then py_install='poetry install'
  elif [ -f "$root/requirements.txt" ]; then py_install='pip install -r requirements.txt'
  else                                       py_install='pip install -e .'
  fi
  _dep '(^|/)(pyproject\.toml|poetry\.lock|requirements.*\.txt|uv\.lock)$' \
       "python deps" "$py_install"
  _dep '(^|/)(build\.gradle(\.kts)?|settings\.gradle(\.kts)?|gradle/libs\.versions\.toml|pom\.xml)$' \
       "JVM build files" "./gradlew --refresh-dependencies  (or reimport in your IDE)"
}
