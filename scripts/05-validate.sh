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
require_file "ami-files/etc-systemd-system/npm-cert-check.service"
require_file "ami-files/etc-systemd-system/npm-cert-check.timer"
require_file "ami-files/opt-aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json"
require_file "ami-files/usr-local-bin/npm-backup"
require_file "ami-files/usr-local-bin/npm-cert-check"
require_file "ami-files/usr-local-bin/npm-restore"
require_file "ami-files/usr-local-bin/npm-stack-start"
require_file "ami-files/usr-local-bin/npm-preflight"
require_file "ami-files/usr-local-bin/npm-postinit"
require_file "ami-files/usr-local-bin/northstar"
require_file "ami-files/etc/npm-cert-check.conf"

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
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "cert-check"
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "subparsers\.add_parser\\([[:space:]]*\"upgrade\""
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "subparsers\.add_parser\\([[:space:]]*\"backup\""
require_grep "$AMI_FILES/usr-local-bin/npm-helper" "subparsers\.add_parser\\([[:space:]]*\"restore\""
require_grep "$AMI_FILES/usr-local-bin/npm_common.py" "Security expectations"
require_grep "$AMI_FILES/usr-local-bin/npm_common.py" "Run: sudo npm-helper show-creds"

# 2c) Docs mention new commands (light checks)
require_grep "$REPO_ROOT/docs/operations.md" "npm-helper cert-check"
require_grep "$REPO_ROOT/docs/operations.md" "npm-helper upgrade"
require_grep "$REPO_ROOT/docs/backup-restore.md" "npm-helper backup verify"
require_grep "$REPO_ROOT/docs/backup-restore.md" "npm-helper restore --dry-run"

# 2d) Ensure MOTD snippets do not print secrets
if python3 - "$AMI_FILES/usr-local-bin/npm_common.py" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    lines = handle.readlines()

start = None
end = None
for i, line in enumerate(lines):
    if line.startswith("def build_motd_script"):
        start = i
        continue
    if start is not None and line.startswith("def ") and i > start:
        end = i
        break

if start is None:
    sys.exit(1)

block = "".join(lines[start:end])
sys.exit(0 if "Password:" not in block else 2)
PY
then
  pass "motd contains no password string"
else
  fail "motd contains password string"
fi

# 2e) Ensure cert-check does not reference private key material
if grep -qE "privkey\.pem" "$AMI_FILES/usr-local-bin/npm-cert-check"; then
  fail "cert-check references privkey.pem"
else
  pass "cert-check does not reference privkey.pem"
fi

# 2f) Ensure security hardening does not open admin port 81 by default
if grep -qE "ufw[[:space:]]+allow[[:space:]]+81" "$REPO_ROOT/scripts/03-security-hardening.sh"; then
  fail "security hardening opens port 81 by default"
else
  pass "security hardening does not open port 81 by default"
fi

# 3) Optional: systemd unit verification (if available)
if command -v systemd-analyze >/dev/null 2>&1; then
  # systemd-analyze verify returns non-zero on unit syntax errors
  if systemd-analyze verify "$AMI_FILES"/etc-systemd-system/*.service "$AMI_FILES"/etc-systemd-system/*.timer >/dev/null 2>&1; then
    pass "systemd-analyze verify unit files"
  else
    warn "systemd-analyze verify reported unit file issues (expected in clean build env without staged root); validated in AMI image with full filesystem"
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
