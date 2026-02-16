# Reliability Scorecard

This AMI publishes reliability evidence as local artifacts generated from validation and harness scripts.

No runtime telemetry is sent externally.

## Goals

- Track deterministic first-boot success outcomes in repeated tests.
- Track upgrade + rollback outcomes from scripted harness runs.
- Track restore pass rate and measured recovery times.
- Keep all metrics local to test artifacts in this repository.

## Artifact locations

- Generated JSON: `metrics/reliability-scorecard-latest.json`
- Generated markdown: `metrics/reliability-scorecard-latest.md`
- Generated restore verification report: `metrics/restore-verify-report-latest.json` (when command scenarios run)
- Periodic restore verification source (on AMI instances): `/var/lib/northstar/npm/restore-verify-latest.json`
- Format examples:
  - `metrics/reliability-scorecard.example.json`
  - `metrics/reliability-scorecard.example.md`

## Generate scorecard artifacts

```bash
scripts/07-reliability-harness.sh --output-dir metrics
```

Disable command execution (env-input mode only):

```bash
scripts/07-reliability-harness.sh --output-dir metrics --no-run-commands
```

Or run validation and emit metrics in one pass:

```bash
scripts/05-validate.sh --emit-metrics
```

## CI Integration

The CI workflow (`.github/workflows/validate.yml`) runs the reliability harness in **env-input mode only**:

```bash
scripts/07-reliability-harness.sh --no-run-commands --output-dir metrics
```

This validates that the harness script runs and emits scorecard artifacts. All command-driven scenarios (backup verify, upgrade dry-run, restore dry-run, etc.) are recorded as `skipped` because they require a live AMI instance.

**Full scenario execution** (backup verify, upgrade dry-run, restore dry-run) requires a live EC2 instance with the AMI. To run the full harness:

1. Launch a test instance from the AMI
2. Run: `scripts/07-reliability-harness.sh --output-dir metrics` (without `--no-run-commands`)
3. Or use a scheduled EC2-based pipeline that launches instances, runs the harness, and shuts down

## Input model

`scripts/07-reliability-harness.sh` accepts run counts and recovery durations via environment variables:

- `FIRST_BOOT_TOTAL`, `FIRST_BOOT_SUCCESS`
- `UPGRADE_TOTAL`, `UPGRADE_SUCCESS`
- `RESTORE_TOTAL`, `RESTORE_SUCCESS`
- `ROLLBACK_RECOVERY_SECONDS`
- `RESTORE_RECOVERY_SECONDS`

Unset values default to `0`.

By default, the harness also attempts run-driven scenarios and records exit codes/timings:

- `npm-helper backup verify`
- `npm-helper upgrade --dry-run`
- `npm-helper restore --dry-run <latest-backup>`
- `npm-helper restore --verify --report-file ... <latest-backup>`
- periodic report ingest from `/var/lib/northstar/npm/restore-verify-latest.json` when present

When command execution is not possible, scenarios are recorded as `skipped` with reasons.

## Acceptance criteria

- Artifact generation is deterministic and repeatable.
- Metrics are written only to local files.
- JSON schema includes scenario metadata (`scenario_count`, `passed`, `failed`, `warned`, `skipped`, durations), success rates, and recovery timing.
