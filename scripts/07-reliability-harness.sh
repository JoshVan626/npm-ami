#!/usr/bin/env bash
# Reliability scorecard artifact generator (local-only, no network publishing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
METRICS_DIR="${REPO_ROOT}/metrics"

usage() {
  cat <<'EOF'
Usage: scripts/07-reliability-harness.sh [--output-dir <dir>] [--no-run-commands]

Inputs are provided via environment variables (defaults are 0):
  FIRST_BOOT_TOTAL, FIRST_BOOT_SUCCESS
  UPGRADE_TOTAL, UPGRADE_SUCCESS
  RESTORE_TOTAL, RESTORE_SUCCESS
  ROLLBACK_RECOVERY_SECONDS
  RESTORE_RECOVERY_SECONDS
EOF
}

RUN_COMMANDS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      METRICS_DIR="$2"
      shift 2
      ;;
    --no-run-commands)
      RUN_COMMANDS=0
      shift
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
RESTORE_REPORT_OUT="${METRICS_DIR}/restore-verify-report-latest.json"
PERIODIC_RESTORE_REPORT="/var/lib/northstar/npm/restore-verify-latest.json"

SCENARIOS_JSON="${METRICS_DIR}/.reliability-scenarios.tmp.jsonl"
: > "$SCENARIOS_JSON"

scenario_entry() {
  local name="$1"
  local status="$2"
  local exit_code="$3"
  local duration="$4"
  local command="$5"
  local reason="${6:-}"
  python3 - "$name" "$status" "$exit_code" "$duration" "$command" "$reason" <<'PY' >> "$SCENARIOS_JSON"
import json
import sys
name, status, exit_code, duration, command, reason = sys.argv[1:7]
obj = {
    "name": name,
    "status": status,
    "exit_code": None if exit_code == "" else int(exit_code),
    "duration_seconds": float(duration),
    "command": command,
}
if reason:
    obj["reason"] = reason
print(json.dumps(obj))
PY
}

run_scenario() {
  local name="$1"
  local command="$2"
  local reason_on_skip="${3:-}"
  local start end duration rc
  if [[ "$RUN_COMMANDS" -ne 1 ]]; then
    scenario_entry "$name" "skipped" "" "0" "$command" "run_commands_disabled"
    return 0
  fi
  start="$(date +%s)"
  if eval "$command"; then
    rc=0
  else
    rc=$?
  fi
  end="$(date +%s)"
  duration="$((end - start))"
  if [[ "$rc" -eq 0 ]]; then
    scenario_entry "$name" "pass" "$rc" "$duration" "$command"
  elif [[ "$rc" -eq 2 ]]; then
    scenario_entry "$name" "warn" "$rc" "$duration" "$command"
  else
    scenario_entry "$name" "fail" "$rc" "$duration" "$command" "$reason_on_skip"
  fi
}

ingest_periodic_restore_report() {
  local report_path="$1"
  if [[ ! -f "$report_path" ]]; then
    scenario_entry "restore_verify_periodic_latest" "skipped" "" "0" "read ${report_path}" "periodic_report_missing"
    return 0
  fi
  python3 - "$report_path" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("restore_verify_periodic_latest|fail||0|read " + path + "|periodic_report_parse_error")
    raise SystemExit(0)

status = str(data.get("status", "unknown")).lower()
duration = float(data.get("duration_seconds", 0.0))
if status in ("pass", "success", "green"):
    out_status = "pass"
elif status in ("warn", "warning", "yellow"):
    out_status = "warn"
elif status in ("fail", "failure", "red"):
    out_status = "fail"
else:
    out_status = "warn"
reason = "" if out_status in ("pass", "warn") else "periodic_report_failed"
print(f"restore_verify_periodic_latest|{out_status}||{duration}|read {path}|{reason}")
PY
}

if [[ "$RUN_COMMANDS" -eq 1 ]]; then
  NPM_HELPER_BIN="/usr/local/bin/npm-helper"
  if [[ ! -x "$NPM_HELPER_BIN" ]]; then
    scenario_entry "backup_verify" "skipped" "" "0" "$NPM_HELPER_BIN backup verify" "npm_helper_missing"
    scenario_entry "upgrade_dry_run" "skipped" "" "0" "$NPM_HELPER_BIN upgrade --dry-run" "npm_helper_missing"
    scenario_entry "restore_dry_run" "skipped" "" "0" "$NPM_HELPER_BIN restore --dry-run <latest_backup>" "npm_helper_missing"
    scenario_entry "restore_verify_report" "skipped" "" "0" "$NPM_HELPER_BIN restore --verify --report-file $RESTORE_REPORT_OUT <latest_backup>" "npm_helper_missing"
  else
    run_scenario "backup_verify" "$NPM_HELPER_BIN backup verify"
    run_scenario "upgrade_dry_run" "$NPM_HELPER_BIN upgrade --dry-run"

    latest_backup="$(ls -1t /var/backups/npm-*.tar.gz 2>/dev/null | head -n 1 || true)"
    if [[ -z "${latest_backup:-}" ]]; then
      scenario_entry "restore_dry_run" "skipped" "" "0" "$NPM_HELPER_BIN restore --dry-run <latest_backup>" "backup_missing"
      scenario_entry "restore_verify_report" "skipped" "" "0" "$NPM_HELPER_BIN restore --verify --report-file $RESTORE_REPORT_OUT <latest_backup>" "backup_missing"
    else
      run_scenario "restore_dry_run" "$NPM_HELPER_BIN restore --dry-run \"$latest_backup\""
      run_scenario "restore_verify_report" "$NPM_HELPER_BIN restore --verify --report-file \"$RESTORE_REPORT_OUT\" \"$latest_backup\""
    fi
  fi
else
  scenario_entry "backup_verify" "skipped" "" "0" "/usr/local/bin/npm-helper backup verify" "run_commands_disabled"
  scenario_entry "upgrade_dry_run" "skipped" "" "0" "/usr/local/bin/npm-helper upgrade --dry-run" "run_commands_disabled"
  scenario_entry "restore_dry_run" "skipped" "" "0" "/usr/local/bin/npm-helper restore --dry-run <latest_backup>" "run_commands_disabled"
  scenario_entry "restore_verify_report" "skipped" "" "0" "/usr/local/bin/npm-helper restore --verify --report-file ${RESTORE_REPORT_OUT} <latest_backup>" "run_commands_disabled"
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name="$(echo "$line" | cut -d'|' -f1)"
  status="$(echo "$line" | cut -d'|' -f2)"
  exit_code="$(echo "$line" | cut -d'|' -f3)"
  duration="$(echo "$line" | cut -d'|' -f4)"
  cmd="$(echo "$line" | cut -d'|' -f5)"
  reason="$(echo "$line" | cut -d'|' -f6)"
  scenario_entry "$name" "$status" "$exit_code" "$duration" "$cmd" "$reason"
done < <(ingest_periodic_restore_report "$PERIODIC_RESTORE_REPORT")

python3 - "$JSON_OUT" "$MD_OUT" \
  "$SCENARIOS_JSON" \
  "$FIRST_BOOT_TOTAL" "$FIRST_BOOT_SUCCESS" \
  "$UPGRADE_TOTAL" "$UPGRADE_SUCCESS" \
  "$RESTORE_TOTAL" "$RESTORE_SUCCESS" \
  "$ROLLBACK_RECOVERY_SECONDS" "$RESTORE_RECOVERY_SECONDS" <<'PY'
import json
import sys
from datetime import datetime, timezone

json_out, md_out, scenarios_file = sys.argv[1], sys.argv[2], sys.argv[3]
fb_total, fb_success = int(sys.argv[4]), int(sys.argv[5])
up_total, up_success = int(sys.argv[6]), int(sys.argv[7])
rs_total, rs_success = int(sys.argv[8]), int(sys.argv[9])
rb_sec, re_sec = float(sys.argv[10]), float(sys.argv[11])

def pct(success: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((success / total) * 100.0, 2)

scenarios = []
with open(scenarios_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line:
            scenarios.append(json.loads(line))

passed = sum(1 for s in scenarios if s.get("status") == "pass")
failed = sum(1 for s in scenarios if s.get("status") == "fail")
warned = sum(1 for s in scenarios if s.get("status") == "warn")
skipped = sum(1 for s in scenarios if s.get("status") == "skipped")
total_duration = round(sum(float(s.get("duration_seconds", 0.0)) for s in scenarios), 3)

payload = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "source": "local_harness_run_driven",
    "run_metadata": {
        "scenario_count": len(scenarios),
        "passed": passed,
        "failed": failed,
        "warned": warned,
        "skipped": skipped,
        "total_duration_seconds": total_duration,
    },
    "scenarios": scenarios,
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
- Source: run-driven local harness artifacts only (no external publishing)

## Success Rates

- First boot success rate: {payload['first_boot']['success_rate_percent']}% ({fb_success}/{fb_total})
- Upgrade success rate: {payload['upgrade']['success_rate_percent']}% ({up_success}/{up_total})
- Restore success rate: {payload['restore']['success_rate_percent']}% ({rs_success}/{rs_total})

## Scenario Run Summary

- Scenario count: {payload['run_metadata']['scenario_count']}
- Passed: {payload['run_metadata']['passed']}
- Failed: {payload['run_metadata']['failed']}
- Warned: {payload['run_metadata']['warned']}
- Skipped: {payload['run_metadata']['skipped']}
- Total scenario duration (seconds): {payload['run_metadata']['total_duration_seconds']}

## Recovery Time

- Rollback recovery time (seconds): {rb_sec}
- Restore recovery time (seconds): {re_sec}
"""
with open(md_out, "w", encoding="utf-8") as f:
    f.write(md)
PY

rm -f "$SCENARIOS_JSON"

echo "Wrote reliability artifacts:"
echo "  - ${JSON_OUT}"
echo "  - ${MD_OUT}"
echo "  - ${RESTORE_REPORT_OUT} (when restore verify scenario runs)"
