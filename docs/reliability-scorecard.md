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

## Runtime reliability reporting

On running AMI instances, operators can view live reliability KPIs computed from the instance's own operational history:

```bash
sudo npm-helper reliability-report
sudo npm-helper reliability-report --json
```

Or via the `northstar` wrapper:

```bash
sudo northstar reliability-report
sudo northstar reliability-report --json
```

This command computes:

- **Backup success rate** -- percentage of successful backup runs from journal history
- **Last successful backup age** -- hours since the most recent successful backup
- **Restore verification pass rate** -- percentage of pass results across all stored verification reports
- **Latest restore verification result** -- status of the most recent verification
- **Last upgrade status** -- outcome of the most recent upgrade attempt
- **Rollback readiness** -- whether a known-good backup and metadata exist for rollback

The `--json` output is designed for integration with fleet monitoring dashboards and compliance evidence collection.

## Runtime health assessment

For a unified operational health check across all subsystems:

```bash
sudo npm-helper health-report
sudo npm-helper health-report --json
```

This evaluates Docker, NPM service, container, init status, backup recency, restore verification, certificate expiry, disk usage, and upgrade state. Each check returns pass/warn/fail, and the overall verdict is the worst status across all checks.
