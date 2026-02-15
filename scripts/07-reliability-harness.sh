#!/usr/bin/env bash
# Reliability scorecard artifact generator (local-only, no network publishing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
METRICS_DIR="${REPO_ROOT}/metrics"

usage() {
  cat <<'EOF'
Usage: scripts/07-reliability-harness.sh [--output-dir <dir>]

Inputs are provided via environment variables (defaults are 0):
  FIRST_BOOT_TOTAL, FIRST_BOOT_SUCCESS
  UPGRADE_TOTAL, UPGRADE_SUCCESS
  RESTORE_TOTAL, RESTORE_SUCCESS
  ROLLBACK_RECOVERY_SECONDS
  RESTORE_RECOVERY_SECONDS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      METRICS_DIR="$2"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$METRICS_DIR"

FIRST_BOOT_TOTAL="${FIRST_BOOT_TOTAL:-0}"
FIRST_BOOT_SUCCESS="${FIRST_BOOT_SUCCESS:-0}"
UPGRADE_TOTAL="${UPGRADE_TOTAL:-0}"
UPGRADE_SUCCESS="${UPGRADE_SUCCESS:-0}"
RESTORE_TOTAL="${RESTORE_TOTAL:-0}"
RESTORE_SUCCESS="${RESTORE_SUCCESS:-0}"
ROLLBACK_RECOVERY_SECONDS="${ROLLBACK_RECOVERY_SECONDS:-0}"
RESTORE_RECOVERY_SECONDS="${RESTORE_RECOVERY_SECONDS:-0}"

JSON_OUT="${METRICS_DIR}/reliability-scorecard-latest.json"
MD_OUT="${METRICS_DIR}/reliability-scorecard-latest.md"

python3 - "$JSON_OUT" "$MD_OUT" \
  "$FIRST_BOOT_TOTAL" "$FIRST_BOOT_SUCCESS" \
  "$UPGRADE_TOTAL" "$UPGRADE_SUCCESS" \
  "$RESTORE_TOTAL" "$RESTORE_SUCCESS" \
  "$ROLLBACK_RECOVERY_SECONDS" "$RESTORE_RECOVERY_SECONDS" <<'PY'
import json
import sys
from datetime import datetime, timezone

json_out, md_out = sys.argv[1], sys.argv[2]
fb_total, fb_success = int(sys.argv[3]), int(sys.argv[4])
up_total, up_success = int(sys.argv[5]), int(sys.argv[6])
rs_total, rs_success = int(sys.argv[7]), int(sys.argv[8])
rb_sec, re_sec = float(sys.argv[9]), float(sys.argv[10])

def pct(success: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((success / total) * 100.0, 2)

payload = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "source": "local_harness",
    "first_boot": {"total": fb_total, "success": fb_success, "success_rate_percent": pct(fb_success, fb_total)},
    "upgrade": {"total": up_total, "success": up_success, "success_rate_percent": pct(up_success, up_total)},
    "restore": {"total": rs_total, "success": rs_success, "success_rate_percent": pct(rs_success, rs_total)},
    "recovery_time_seconds": {
        "rollback_path": rb_sec,
        "restore_path": re_sec,
    },
}

with open(json_out, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=True)
    f.write("\n")

md = f"""# Reliability Scorecard (Latest Local Run)

- Generated at (UTC): {payload['generated_at_utc']}
- Source: local harness artifacts only (no external publishing)

## Success Rates

- First boot success rate: {payload['first_boot']['success_rate_percent']}% ({fb_success}/{fb_total})
- Upgrade success rate: {payload['upgrade']['success_rate_percent']}% ({up_success}/{up_total})
- Restore success rate: {payload['restore']['success_rate_percent']}% ({rs_success}/{rs_total})

## Recovery Time

- Rollback recovery time (seconds): {rb_sec}
- Restore recovery time (seconds): {re_sec}
"""
with open(md_out, "w", encoding="utf-8") as f:
    f.write(md)
PY

echo "Wrote reliability artifacts:"
echo "  - ${JSON_OUT}"
echo "  - ${MD_OUT}"
