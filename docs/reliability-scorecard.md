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
- Format examples:
  - `metrics/reliability-scorecard.example.json`
  - `metrics/reliability-scorecard.example.md`

## Generate scorecard artifacts

```bash
scripts/07-reliability-harness.sh --output-dir metrics
```

Or run validation and emit metrics in one pass:

```bash
scripts/05-validate.sh --emit-metrics
```

## Input model

`scripts/07-reliability-harness.sh` accepts run counts and recovery durations via environment variables:

- `FIRST_BOOT_TOTAL`, `FIRST_BOOT_SUCCESS`
- `UPGRADE_TOTAL`, `UPGRADE_SUCCESS`
- `RESTORE_TOTAL`, `RESTORE_SUCCESS`
- `ROLLBACK_RECOVERY_SECONDS`
- `RESTORE_RECOVERY_SECONDS`

Unset values default to `0`.

## Acceptance criteria

- Artifact generation is deterministic and repeatable.
- Metrics are written only to local files.
- JSON schema includes run counts, success rates, and recovery timing.
