#!/usr/bin/env bash
# Build-time validation gate for NPM Hardened Edition AMI
# Purpose: fail fast on regressions that would break first boot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AMI_FILES="$REPO_ROOT/ami-files"

failures=0

pass() {
  echo "PASS: $*"
}

warn() {
  echo "WARN: $*"
}

fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

require_file() {
  local rel="$1"
  local path="$REPO_ROOT/$rel"
  if [[ -f "$path" ]]; then
    pass "exists: $rel"
  else
    fail "missing: $rel"
  fi
}

require_grep() {
  local file="$1"
  local pattern="$2"
  if [[ ! -f "$file" ]]; then
    fail "missing file for grep: $file"
    return 0
  fi
  if grep -qE "$pattern" "$file"; then
    pass "grep ok: $(basename "$file") matches /$pattern/"
  else
    fail "grep failed: $(basename "$file") missing /$pattern/"
  fi
}

python_pycompile() {
  local files=("$@")

  # Filter to existing files (avoid py_compile failing on a missing file twice)
  local existing=()
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      existing+=("$f")
    fi
  done

  if [[ ${#existing[@]} -eq 0 ]]; then
    warn "no python files found to compile"
    return 0
  fi

  if python3 -m py_compile "${existing[@]}" >/dev/null 2>&1; then
    pass "python3 -m py_compile (${#existing[@]} files)"
  else
    fail "python3 -m py_compile failed"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AMI Validation Gate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Repo root: $REPO_ROOT"
echo "AMI files: $AMI_FILES"
echo ""

# 1) Expected payload files
require_file "ami-files/opt-npm/docker-compose.yml"
require_file "ami-files/etc-systemd-system/npm.service"
require_file "ami-files/etc-systemd-system/npm-preflight.service"
require_file "ami-files/etc-systemd-system/npm-init.service"
require_file "ami-files/etc-systemd-system/npm-postinit.service"
require_file "ami-files/etc-systemd-system/npm-backup.service"
require_file "ami-files/etc-systemd-system/npm-backup.timer"
require_file "ami-files/opt-aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json"
require_file "ami-files/usr-local-bin/npm-backup"
require_file "ami-files/usr-local-bin/npm-restore"
require_file "ami-files/usr-local-bin/npm-stack-start"
require_file "ami-files/usr-local-bin/npm-preflight"
require_file "ami-files/usr-local-bin/npm-postinit"

# 2) Python validation (compile)
PY_CANDIDATES=(
  "$AMI_FILES/usr-local-bin/npm-init.py"
  "$AMI_FILES/usr-local-bin/npm_common.py"
  "$AMI_FILES/usr-local-bin/npm-helper"
)

# Include any additional python modules in usr-local-bin
if compgen -G "$AMI_FILES/usr-local-bin/*.py" >/dev/null; then
  for f in "$AMI_FILES"/usr-local-bin/*.py; do
    PY_CANDIDATES+=("$f")
  done
fi

# Dedupe (preserve order)
PY_FILES=()
declare -A seen
for f in "${PY_CANDIDATES[@]}"; do
  if [[ -n "${f:-}" && -z "${seen[$f]+x}" ]]; then
    seen[$f]=1
    PY_FILES+=("$f")
  fi
done

python_pycompile "${PY_FILES[@]}"

# 2b) Lightweight v1.0 contract checks (no execution)
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "subparsers\.add_parser\\([[:space:]]*\"update-os\""
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "subparsers\.add_parser\\([[:space:]]*\"diagnostics\""
require_grep "$AMI_FILES/usr-local-bin/npm_common.py" "Security expectations"

# 3) Optional: systemd unit verification (if available)
if command -v systemd-analyze >/dev/null 2>&1; then
  # systemd-analyze verify returns non-zero on unit syntax errors
  if systemd-analyze verify "$AMI_FILES"/etc-systemd-system/*.service "$AMI_FILES"/etc-systemd-system/*.timer >/dev/null 2>&1; then
    pass "systemd-analyze verify unit files"
  else
    fail "systemd-analyze verify reported unit file issues"
  fi
else
  warn "systemd-analyze not available; skipping unit file verification"
fi

# 4) Optional: compose file syntax (if docker is available)
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    if docker compose -f "$AMI_FILES/opt-npm/docker-compose.yml" config >/dev/null 2>&1; then
      pass "docker compose config"
    else
      fail "docker compose config failed"
    fi
  else
    warn "docker compose plugin not available; skipping compose validation"
  fi
else
  warn "docker not available; skipping compose validation"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$failures" -eq 0 ]]; then
  echo "✓ Validation PASSED"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "✗ Validation FAILED ($failures issue(s))"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi
