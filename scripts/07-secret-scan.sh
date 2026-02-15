#!/usr/bin/env bash
# Lightweight high-signal secret scan for repository validation.
# Fails build on common credential/key leakage patterns.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

failures=0

run_check() {
  local label="$1"
  local pattern="$2"
  local output

  output="$(rg -n --pcre2 --hidden --glob '!**/.git/**' --glob '!scripts/07-secret-scan.sh' "$pattern" "$REPO_ROOT" || true)"
  if [[ -n "$output" ]]; then
    echo "FAIL: $label"
    echo "$output"
    failures=$((failures + 1))
  else
    echo "PASS: $label"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Scan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_check "Private key block markers" "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
run_check "AWS access key IDs (AKIA)" "\\bAKIA[0-9A-Z]{16}\\b"
run_check "AWS STS key IDs (ASIA)" "\\bASIA[0-9A-Z]{16}\\b"
run_check "AWS secret access keys assigned in code/config" "(?i)aws_secret_access_key\\s*[:=]\\s*['\\\"]?[A-Za-z0-9/+=]{20,}['\\\"]?"
run_check "GitHub personal access tokens" "\\bghp_[A-Za-z0-9]{36}\\b"
run_check "Slack bot/user tokens" "\\bxox[baprs]-[A-Za-z0-9-]{10,}\\b"

if [[ "$failures" -gt 0 ]]; then
  echo "✗ Secret scan failed ($failures finding group(s))."
  exit 1
fi

echo "✓ Secret scan passed."
exit 0
