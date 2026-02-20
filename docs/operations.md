# Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring

**by Northstar Cloud Solutions**

This AMI includes a few opinionated tools and services to make NPM easier to
run in production.

---

## Recommended deployment (hardened default)

To reduce choice overload and get a single, supportable path: use the **Terraform** template with **`deploy/terraform/examples/secure.tfvars`** (or the **CloudFormation** template with **`deploy/cloudformation/examples/secure-params.json`**). This enables the instance profile (CloudWatch, S3, Secrets Manager, EC2 tagging, SSM), restricted admin ports, and optional EIP in one step. See [`deploy/README.md`](../deploy/README.md) for the secure default labels and full options.

---

## NPM Initialization (First Boot)

On first boot, the boot flow is:

- `npm-preflight.service` → fast checks and clear failure reasons
- `npm-init.service` → one-time credential initialization
- `npm-postinit.service` → post-init health summary

You can see the current state in:

- The SSH login banner (MOTD) under **Initialization Status**
- `sudo npm-helper status`

On first boot, `npm-init.service` runs once to:

1. Wait for the NPM SQLite database to become ready (up to ~300 seconds)
2. Generate a secure random admin password
3. Update the database with the new credentials
4. Write credentials to a root-only file
5. Update the SSH login banner (MOTD) with a non-sensitive status message

The wait time accounts for slow instance types or cold container pulls.
If initialization is interrupted before completion, rerunning `npm-init.service`
reuses the existing credentials file when present to avoid accidental password churn.

### Admin email

The default admin email is `admin@example.com` (NPM's default).

To use a different email, set the `NPM_ADMIN_EMAIL` environment variable before
first boot. The init service reads `/etc/northstar/npm-init.env` if present.

**EC2 user-data (cloud-init) example:**

```yaml
#cloud-config
write_files:
  - path: /etc/northstar/npm-init.env
    owner: root:root
    permissions: '0600'
    content: |
      NPM_ADMIN_EMAIL=admin@yourdomain.com
runcmd:
  - [ systemctl, daemon-reload ]
```

If you prefer, you can also set it in `/etc/environment`:

```bash
NPM_ADMIN_EMAIL=admin@yourdomain.com
```

Or create a systemd override for `npm-init.service`:

```bash
sudo systemctl edit npm-init
```

Add:

```ini
[Service]
Environment="NPM_ADMIN_EMAIL=admin@yourdomain.com"
```

This must be set **before the first boot initialization runs**. If you need to
change the email after initialization, update the NPM database directly via the
web UI.

### Troubleshooting init failures

If NPM doesn't come up after first boot:

```bash
# Preflight status + logs (runs before init)
sudo systemctl status npm-preflight.service
sudo journalctl -u npm-preflight.service -n 200 --no-pager

# Check init service status
sudo systemctl status npm-init

# View detailed init logs
sudo journalctl -u npm-init -xe

# Post-init status + logs (runs after init)
sudo systemctl status npm-postinit.service
sudo journalctl -u npm-postinit.service -n 200 --no-pager

# If post-init failed and you want to re-run it after fixing the issue:
sudo rm -f /var/lib/northstar/npm/postinit-ok /var/lib/northstar/npm/postinit-status
sudo systemctl start npm-postinit.service

# Restart the NPM stack
sudo systemctl restart npm

# Re-run initialization (safe to run multiple times)
sudo systemctl restart npm-init
```

Common causes:

- Container image pull timeout (retry usually fixes it)
- Insufficient instance resources (use t3.small or larger)
- Docker service not ready (check `systemctl status docker`)

---

## First Boot Recovery (Preflight / Init / Post-Init)

Quick status:

- Run: `sudo npm-helper status`
- The SSH login banner (MOTD) also shows **Initialization Status** at login.

View logs (most recent 200 lines):

```bash
sudo journalctl -u npm-preflight.service -n 200 --no-pager
sudo journalctl -u npm-init.service -n 200 --no-pager
sudo journalctl -u npm-postinit.service -n 200 --no-pager
sudo journalctl -u npm.service -n 200 --no-pager
```

Safe re-run commands (after fixing the underlying issue):

```bash
sudo systemctl start npm-preflight.service
sudo systemctl start npm-init.service
sudo systemctl start npm-postinit.service
```

Common blockers:

- No outbound internet access (image pull fails)
- Insufficient disk space on `/`
- Docker daemon not running
- Security Group or routing prevents reaching port `81/tcp` from your network

---

## Systemd services

Key services:

- `docker.service` – Docker engine
- `npm.service` – NPM Docker stack
- `npm-preflight.service` – first-boot preflight checks
- `npm-init.service` – one-time first-boot initialization
- `npm-postinit.service` – first-boot post-init health summary
- `npm-backup.timer` – daily backup timer
- `npm-restore-verify.timer` – periodic non-destructive restore verification timer
- `npm-health-endpoint.service` – HTTP health endpoint on 127.0.0.1:9180 (configurable via `/etc/default/npm-health-endpoint`)
- `npm-cert-check.timer` – daily certificate expiry check
- `npm-health-report.timer` – daily automated health assessment (emits `NORTHSTAR_HEALTH_REPORT`)
- `amazon-cloudwatch-agent.service` – CloudWatch log shipping

Basic commands:

```bash
# Check status
sudo systemctl status npm
sudo systemctl status docker
sudo systemctl status amazon-cloudwatch-agent

# View logs
sudo journalctl -u npm
sudo journalctl -u amazon-cloudwatch-agent

# Restart NPM stack
sudo systemctl restart npm
```

`npm.service` will retry automatically if `docker compose up -d` or the follow-up
container health check fails (e.g., transient network/pull issues). If the stack
is not coming up, check:

- `sudo systemctl status npm` for recent restart attempts
- `sudo journalctl -u npm` for compose output and container state summaries
- `docker compose ps` in `/opt/npm` to see per-container status

---

## CLI: npm-helper (or northstar)

`npm-helper` is installed under `/usr/local/bin`. A branded wrapper (`northstar`)
is also available and recommended. It provides these main subcommands:

### Show current admin credentials

```bash
sudo npm-helper show-admin
sudo npm-helper show-creds
```

Outputs the current admin username and credentials location. Credentials are
stored at `/root/.northstar/npm-admin-credentials` (root-only). Use `show-creds`
to display the password (root only).

### Rotate admin password

```bash
sudo npm-helper rotate-admin
```

What it does:

1. Waits for the NPM SQLite database to be ready.
2. Generates a new strong random password.
3. Updates the NPM `auth` table with the new bcrypt hash.
4. Writes the new credentials to a root-only credentials file.
5. Updates the MOTD banner (no secrets in MOTD).

Use this whenever you want to rotate the admin password without touching the
web UI.

### Status overview

```bash
sudo npm-helper status
```

Shows:

- Docker service status
- `npm` service status
- Container status from `docker compose ps`
- Initialization markers and core systemd unit states
- Admin UI access posture (UFW allowlist)
- Backup status (last run/success/failure)
- Certificate expiry summary (next expiry, days remaining)

This is a quick way to check if the system is healthy.

Additional opt-in commands:

- `sudo npm-helper health-report` – unified pass/warn/fail health assessment across all subsystems (backup, restore, certs, disk, upgrade state); emits `NORTHSTAR_HEALTH_REPORT` structured log for CloudWatch
- `sudo npm-helper health-report --json` – machine-readable JSON health report for fleet dashboards or monitoring
- **HTTP health endpoint** – `npm-health-endpoint.service` serves `GET /health` on port 9180 (127.0.0.1 by default) with JSON `{"status":"pass|warn|fail","checks":[...],"timestamp":"..."}` for load balancers (ALB/NLB) and monitoring tools
- `sudo npm-helper reliability-report` – runtime reliability KPIs computed from instance history (backup success rate, restore verification pass rate, rollback readiness); persists daily snapshot to KPI history
- `sudo npm-helper reliability-report --json` – machine-readable JSON reliability KPIs
- `sudo npm-helper reliability-report --history` – show KPI trend summary from daily snapshots (7d/30d averages)
- `sudo npm-helper reliability-report --history --json` – machine-readable trend output
- `sudo npm-upgrade-ami` – guided blue/green AMI upgrade checklist (backup + launch + restore + cutover steps)
- `sudo npm-pre-upgrade-check` – pre-upgrade compatibility (current image, DB integrity, proxy/cert counts, cert expiry); used automatically by `npm-update-container` and `npm-upgrade-ami`
- `sudo npm-cutover-eip <allocation-id> <new-instance-id> [--region REGION] [--yes]` – scripted EIP reassociation for blue/green cutover (run from any host with AWS CLI)
- `sudo npm-migrate-import [--detect-only] <path>` – import NPM data from an existing installation (DIY Docker, Bitnami, etc.); `--detect-only` validates and reports source type without importing
- `sudo npm-helper compliance-report` – runtime CIS benchmark compliance verification (checks SSH, UFW, sysctl, fail2ban against CIS Ubuntu 22.04 LTS Benchmark v1.0.0)
- `sudo npm-helper compliance-report --json` – machine-readable JSON compliance evidence for audit packs
- `sudo npm-helper update-os` – run a one-click `apt-get update` + `apt-get upgrade` (may require reboot)
- `sudo npm-helper diagnostics --json` – emit non-sensitive diagnostic JSON for support/troubleshooting
- `sudo npm-helper admin-access enable --cidr <ip>/32` – allowlist port 81 from a trusted IP
- `sudo npm-helper admin-access disable` – remove allowlist rules for port 81
- `sudo npm-helper cert-check` – run the certificate expiry check immediately
- `sudo npm-helper upgrade --dry-run` – preflight + show planned steps
- `sudo npm-helper upgrade` – run a backup-first upgrade using the existing compose pins
- `sudo npm-update-container <tag>` – backup-first in-place image tag update with health check + rollback attempt
- `sudo npm-helper set-channel stable|edge` – switch NPM image channel (stable=pinned, edge=latest)
- `sudo npm-helper upgrade --auto-rollback` – run upgrade and automatically roll back if post-upgrade health checks fail
- `sudo npm-helper rollback --dry-run` – show rollback plan from last known good metadata
- `sudo npm-helper rollback` – restore last known good backup + prior image metadata
- `sudo npm-helper backup verify` – verify the latest backup archive
- `sudo npm-backup-s3-check` – validate S3 bucket config (bucket exists, IAM write access)
- `sudo npm-helper restore --dry-run <backup>` – validate a restore without changes
- `sudo npm-helper restore --verify <backup>` – generate machine-readable restore verification report
- `sudo npm-restore-verify` – run periodic restore verification workflow once
- `sudo northstar observability status` – inspect opt-in CloudWatch baseline state
- `sudo northstar observability enable --dry-run` – preview dashboard/alarm actions and IAM expectations
- `sudo northstar observability enable` – enable CloudWatch baseline (agent + dashboard + alarms)
- `sudo northstar observability enable --alarm-action-arn arn:aws:sns:...` – opt-in SNS alarm notifications (repeatable)
- `sudo northstar observability enable --ok-action-arn arn:aws:sns:...` – opt-in SNS OK notifications (repeatable)
- `sudo northstar observability disable` – disable baseline and remove created CloudWatch resources

---

## HTTP health endpoint (ALB/NLB, Datadog, etc.)

The `npm-health-endpoint.service` exposes an HTTP health endpoint returning JSON for load balancers and monitoring tools:

| Property | Default |
|----------|---------|
| **Bind** | 127.0.0.1 (localhost only) |
| **Port** | 9180 |
| **Path** | `/health` |
| **Response** | `{"status":"pass|warn|fail","checks":[...],"timestamp":"..."}` |

To enable external health checks (e.g. ALB target group), bind to `0.0.0.0` and open port 9180 in your security group:

```bash
# /etc/default/npm-health-endpoint
NPM_HEALTH_BIND=0.0.0.0
NPM_HEALTH_PORT=9180
```

Then restart the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart npm-health-endpoint
```

For Terraform/CloudFormation target groups, use `GET /health` on port 9180; healthy response is HTTP 200 with `"status":"pass"`. HTTP 503 indicates `"status":"fail"`.

---

## Certificate expiry monitoring

A daily systemd timer checks NPM-managed certificates and logs warnings when
any certificate is within the configured threshold.

Run it manually:

```bash
sudo npm-helper cert-check
```

Configuration file (threshold days):

```ini
/etc/npm-cert-check.conf
```

To change the warning threshold, edit `threshold_days` in that file and rerun the
check or wait for the next timer run.

Disable the timer:

```bash
sudo systemctl disable --now npm-cert-check.timer
```

If CloudWatch Agent is enabled, warnings include a `NORTHSTAR_CERT_EXPIRY_WARN`
log line for easy alerting.

---

## Upgrade safely

Use the upgrade helper to perform a backup-first upgrade using the **existing**
compose file pins (no automatic version changes).

Dry-run preflight:

```bash
sudo npm-helper upgrade --dry-run
```

Upgrade:

```bash
sudo npm-helper upgrade
```

The command prints rollback steps using the latest backup and `npm-helper restore`.

Automatic rollback (opt-in):

```bash
sudo npm-helper upgrade --auto-rollback
```

Manual rollback from captured metadata:

```bash
sudo npm-helper rollback --dry-run
sudo npm-helper rollback
```

Rollback metadata files:

- `/var/lib/northstar/npm/upgrade/last-attempt.json`
- `/var/lib/northstar/npm/upgrade/last-known-good.json`

Each file records backup path, previous image tag, target image tag, status, and timestamps.

---

## Logs & CloudWatch

The CloudWatch Agent is configured to ship:

- `/var/log/syslog`
- `/var/log/auth.log`
- `/var/lib/docker/containers/*/*-json.log`
- `/opt/npm/data/logs/*_access.log` (Nginx proxy access logs)
- `/opt/npm/data/logs/*_error.log` (Nginx proxy error logs)

into a log group named:

```text
/northstar-cloud-solutions/npm
```

with per-instance log streams:

- `{instance_id}-syslog` -- OS system log
- `{instance_id}-auth` -- SSH and authentication events
- `{instance_id}-docker` -- Docker container stdout/stderr
- `{instance_id}-nginx-access` -- Nginx proxy host access logs (all proxy hosts combined)
- `{instance_id}-nginx-error` -- Nginx proxy host error logs (all proxy hosts combined)

You can view these in:

- AWS Console → CloudWatch → Logs → Log groups → `/northstar-cloud-solutions/npm`

This is useful for:

- SSH login attempts
- System service failures
- General OS-level troubleshooting
- Nginx request traffic analysis, upstream errors, and proxy host debugging
- Identifying 4xx/5xx error patterns across proxy hosts

If the agent is not installed (for example, because the `amazon-cloudwatch-agent` apt
package was unavailable during AMI bake), the application will continue to function
normally without CloudWatch logs/metrics. You can install the agent later using apt
on running instances if needed.

---

## Where NPM keeps its data

NPM runs in Docker and stores its state in:

- `/opt/npm/data` – configuration, SQLite DB
- `/opt/npm/letsencrypt` – TLS certificates

These paths are:

- Mounted into the NPM container
- Included in backup archives (`npm-backup` / `npm-restore`)
- Preserved across instance reboots

For support and reproducibility, a build manifest is written at bake time to:

```bash
/opt/northstar/build-manifest.txt
```

This manifest includes the build timestamp (UTC), OS release information, kernel
version, Docker version (if available), best-effort NPM container image tags, and a
dpkg package snapshot. It is owned by `root:root` and world-readable (`0644`) and
does not contain secrets.

---

## Backups

Backups are managed by `npm-backup` and configured in `/etc/npm-backup.conf`.

### Retention requirements

The `[backup] local_retention` setting **must be 1 or greater**. Setting it to 0
will cause `npm-backup` to exit with an error. This prevents unbounded disk
growth from accumulating backup files.

Recommended: `local_retention = 7` (or higher for critical environments).

### Disk usage

Each backup archive is typically 1–10 MB depending on your NPM configuration
and certificate count. Monitor `/var/backups` disk usage, especially on
smaller EBS volumes.

### S3 uploads

To enable S3 uploads:

1. Attach an IAM role with `s3:PutObject` permission to the instance
2. Set `s3_bucket` in `/etc/npm-backup.conf`
3. Ensure the AWS CLI is installed (pre-installed on this AMI)

If the instance lacks proper IAM permissions or the AWS CLI, S3 upload will
fail with a warning but local backup will still succeed.

See [Backup & Restore](./backup-restore.md) for full configuration, S3 offsite replication and lifecycle guidance, and `npm-backup-s3-check` for S3 validation.

---

## Restore

Use `npm-restore` to restore from a backup archive.

### Trust model

**Only restore archives created by `npm-backup` on trusted instances.**

The restore script validates archive contents before extraction and will
**refuse to extract** archives containing paths outside the expected
directories (`opt/npm/data`, `opt/npm/letsencrypt`). This prevents malicious
or corrupted archives from overwriting system files.

If you see an error like:

```
✗ Error: Archive contains paths outside allowed directories!
```

The archive may be corrupted, tampered with, or created by a different tool.
Do not attempt to bypass this check.

See [Backup & Restore](./backup-restore.md) for restore procedures.

### Post-restore application validation

After a successful restore, the `npm-restore` script automatically performs application-level validation beyond the basic HTTP health check:

1. **Database integrity** -- Runs `PRAGMA integrity_check` on the restored SQLite database
2. **User table** -- Verifies the `user` table exists and contains at least one admin user
3. **Proxy host schema** -- Confirms the `proxy_host` table is present in the restored database
4. **API validation** -- Queries the NPM REST API (`/api/nginx/proxy-hosts`) to confirm the application is serving data

These checks are non-blocking: if any check fails, a warning is printed and the structured log line `NORTHSTAR_RESTORE_VALIDATE` is emitted for CloudWatch alerting, but the restore is still considered successful at the file level.

### Backup verification with database checks

The `npm-helper restore --verify` command now includes database integrity checks:

- Extracts `database.sqlite` from the backup archive to a temporary directory
- Runs `PRAGMA integrity_check` to detect corruption
- Verifies `user` and `proxy_host` table schemas are present
- Records all results under the `"database_checks"` key in the JSON verification report

This ensures backups contain a structurally sound, non-corrupt database.

---

## Advanced: External database (MySQL / PostgreSQL)

By default, NPM uses SQLite stored under `/opt/npm/data`. The AMI's backup and restore tools, as well as first-boot init, are designed for this default. For operators who outgrow SQLite (e.g. higher write load or multi-instance sharing), Nginx Proxy Manager upstream supports **MySQL/MariaDB** and **PostgreSQL** via environment variables.

- **SQLite (default):** Fully supported. `npm-backup` and `npm-restore` include the database; `npm-init` seeds the admin user into the local DB.
- **External DB (advanced):** You configure the NPM container to use an external database. Init will still seed the DB if it is empty. **Backup and restore** for database content are **customer-managed** (e.g. RDS snapshots, `mysqldump`/`pg_dump`). The AMI's `npm-backup`/`npm-restore` remain file-based for config and certificates (`/data` and `/etc/letsencrypt`); when using an external DB, the SQLite file under `/opt/npm/data` is not used for NPM's main data, so you can exclude it from backup or use it only for local cache if applicable.

### MySQL/MariaDB environment variables

Set these in your compose override or environment (see example below):

| Variable | Description |
|----------|-------------|
| `DB_MYSQL_HOST` | Database host (e.g. RDS endpoint) |
| `DB_MYSQL_PORT` | Port (default: 3306) |
| `DB_MYSQL_USER` | Database user |
| `DB_MYSQL_PASSWORD` | Database password |
| `DB_MYSQL_NAME` | Database name |

Optional SSL: `DB_MYSQL_SSL`, `DB_MYSQL_SSL_REJECT_UNAUTHORIZED`, `DB_MYSQL_SSL_VERIFY_IDENTITY`.

### PostgreSQL environment variables

| Variable | Description |
|----------|-------------|
| `DB_POSTGRES_HOST` | Database host |
| `DB_POSTGRES_PORT` | Port (default: 5432) |
| `DB_POSTGRES_USER` | Database user |
| `DB_POSTGRES_PASSWORD` | Database password |
| `DB_POSTGRES_NAME` | Database name |

See [Nginx Proxy Manager upstream documentation](https://github.com/NginxProxyManager/nginx-proxy-manager) for the latest variables and behavior. An example override file is provided as `docker-compose.external-db.example.yml` in `/opt/npm/` (if installed from the AMI); use it as a reference and merge the `environment` section into your running compose setup.

### Using AWS RDS

When using Amazon RDS for MySQL or PostgreSQL, consider the following:

| Topic | Guidance |
|-------|----------|
| **Security group** | Allow inbound from the NPM EC2 instance's security group on port 3306 (MySQL) or 5432 (PostgreSQL). EC2 → RDS traffic must be permitted. |
| **Parameter groups** | For MySQL: set `character_set_server` (e.g. `utf8mb4`), `wait_timeout` and `interactive_timeout` as needed. For PostgreSQL: adjust `shared_buffers` and `max_connections` per RDS size. |
| **IAM database auth** | RDS supports IAM authentication for MySQL and PostgreSQL. See [RDS IAM authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html) for setup. NPM uses standard env vars for credentials; IAM auth requires token generation. |
| **RDS Proxy** | For connection pooling and failover, consider [RDS Proxy](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html). Point `DB_MYSQL_HOST` or `DB_POSTGRES_HOST` to the Proxy endpoint instead of the RDS instance. |

**Terraform snippet (RDS MySQL + security group):**

```hcl
resource "aws_security_group" "rds" {
  name_prefix = "npm-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.npm_ec2.id]
    description     = "NPM EC2 to RDS MySQL"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "npm" {
  identifier           = "npm-mysql"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = "nginx_proxy_manager"
  username             = "npm"
  password             = var.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  # ... subnet_group, multi_az, backup_retention, etc.
}
```

For PostgreSQL, use `engine = "postgres"`, `engine_version = "15"` (or preferred), and change the security group ingress to port 5432.

---

## Support Bundles

The `npm-support-bundle` command collects diagnostic information for
troubleshooting:

```bash
sudo npm-support-bundle
```

### Storage location

Bundles are stored under `/var/backups` with names like:

```
npm-support-YYYYMMDDHHMMSS.tar.gz
```

### Cleanup

Support bundles are **not automatically pruned**. To remove bundles older than
14 days:

```bash
sudo find /var/backups -maxdepth 1 -name 'npm-support-*.tar.gz' -mtime +14 -delete
```

Consider adding this to a cron job if you generate bundles frequently.

---

## Instance Tagging (Fleet Visibility)

On first boot, the AMI attempts to tag the EC2 instance with Northstar product metadata using the attached IAM role. This is best-effort and non-blocking; if IAM permissions are missing, initialization continues normally.

Tags applied:

- `northstar:product` = `npm-hardened-edition`
- `northstar:init-status` = `complete`
- `northstar:init-timestamp` = ISO 8601 UTC timestamp
- `northstar:ami-build` = build timestamp from `/opt/northstar/build-manifest.txt` (if available)

Required IAM permission: `ec2:CreateTags` scoped to the instance.

These tags enable fleet inventory filtering in the EC2 console and are useful for operators managing multiple NPM instances.

---

## Compliance Verification

The `compliance-report` command performs runtime verification of CIS benchmark hardening controls on a running instance. This provides live evidence that security controls have not drifted since AMI bake.

```bash
sudo npm-helper compliance-report
sudo npm-helper compliance-report --json
```

Or via the wrapper:

```bash
sudo northstar compliance-report
sudo northstar compliance-report --json
```

The report checks SSH configuration, UFW firewall state, sysctl kernel parameters, and fail2ban status against the CIS Ubuntu Linux 22.04 LTS Benchmark v1.0.0 mapping documented in [`docs/security.md`](./security.md).

The `--json` output is designed for attachment to audit evidence packs.

---

## SSM Session Manager Access (No-SSH Operations)

For enterprises that prohibit SSH access, the AMI supports AWS Systems Manager Session Manager as an alternative management path. When the instance has an IAM role with the `AmazonSSMManagedInstanceCore` managed policy attached (included in the IaC templates), operators can connect without opening port 22:

```bash
aws ssm start-session --target <instance-id> --region <region>
```

All `npm-helper`, `northstar`, and operational commands work identically over SSM sessions. When using SSM exclusively, you can remove the SSH (port 22) ingress rule from your security group for a stricter security posture.

The Terraform and CloudFormation templates in `deploy/` attach the SSM managed policy automatically when `create_instance_profile` is enabled.

---

## Blue/Green AMI Upgrade

The recommended upgrade path for production instances is an immutable blue/green replacement: launch a new instance from the latest AMI, restore data, verify, and cut over traffic.

The `npm-upgrade-ami` command automates the preparation phase:

```bash
sudo npm-upgrade-ami
sudo npm-upgrade-ami --checklist-file /tmp/upgrade-checklist.txt
```

Or via the wrapper:

```bash
sudo northstar upgrade-ami
```

This command:

1. Ensures a fresh backup exists (creates one if the latest is older than 1 hour)
2. Collects instance metadata (instance ID, region, current AMI)
3. Generates a step-by-step checklist with copy-paste commands for:
   - Transferring the backup to the new instance
   - Launching a replacement instance via Terraform/CloudFormation
   - Restoring the backup on the new instance
   - Running health and compliance verification
   - Cutting over traffic (EIP reassociation or DNS update)
   - Decommissioning the old instance

The command does not launch new instances automatically -- it provides a guided, auditable checklist.

### Scripted cutover primitives

For automation or CI, you can run individual cutover steps instead of following the checklist by hand:

- **`npm-upgrade-ami`** (or **`northstar upgrade-ami`**): Use when you want the full checklist (backup, metadata, and copy-paste steps). Run on the **old** instance before launching the new one.
- **`npm-cutover-eip <allocation-id> <new-instance-id> [--region REGION] [--yes]`** (or **`northstar cutover-eip ...`**): Reassociates an Elastic IP to the new instance. Run from any host with AWS CLI and IAM permissions (`ec2:DescribeAddresses`, `ec2:DisassociateAddress`, `ec2:AssociateAddress`). Use after you have launched the new instance, restored the backup, and verified health (e.g. `npm-helper health-report` on the new instance). The `--yes` flag skips the confirmation prompt.

Example flow: run `npm-upgrade-ami` on the old instance → launch new instance (Terraform/Console) → restore on new instance → verify with `npm-helper health-report` → run `npm-cutover-eip eipalloc-xxx i-newinstanceid --region us-east-1 --yes` → decommission old instance when ready.

---

## Migration from Existing NPM

The `npm-migrate-import` command imports data from an existing NPM installation (DIY Docker, Bitnami, or another vendor's AMI) into the Northstar AMI:

```bash
sudo npm-migrate-import /tmp/npm-data/
sudo npm-migrate-import /tmp/npm-export.tar.gz
```

Or via the wrapper:

```bash
sudo northstar migrate-import /tmp/npm-data/
```

**Prerequisites:** Transfer your existing NPM data directory to the instance first (via SCP, S3, or other method). The source must contain at minimum a `database.sqlite` file.

The script:

1. Validates the source data structure and runs database integrity pre-checks
2. Stops the NPM stack and creates a safety backup of current data
3. Imports data into `/opt/npm/data` and `/opt/npm/letsencrypt`
4. Fixes ownership and permissions
5. Starts NPM and runs health and application-level validation
6. Emits `NORTHSTAR_MIGRATE_IMPORT` structured log for CloudWatch

If anything goes wrong, pre-migration data is preserved in timestamped `.pre-migrate-*` directories for rollback.

### Validated import paths

The script detects common source types (Bitnami, Docker default, Northstar/AMI backup) and reports **Detected source:** in the output. Use **`--detect-only`** to validate a path and see the detected type without importing:

```bash
sudo npm-migrate-import --detect-only /tmp/npm-data/
```

| Source | Where to find data | How to prepare for import |
|--------|--------------------|----------------------------|
| **Bitnami NPM** | On the Bitnami host: `~/stack/nginx-proxy-manager/data/` (or similar; check Bitnami docs for your install). Contains `database.sqlite`. | Copy the `data` directory (and `letsencrypt` if present) to this instance, e.g. `scp -r user@source:/path/to/data /tmp/npm-data/`. Then run `npm-migrate-import /tmp/npm-data/`. |
| **DIY Docker** | Typical mount: `./data` and `./letsencrypt` next to your `docker-compose.yml`. The directory that contains `database.sqlite` is the data dir. | Copy that directory to this instance, or create a tarball: `tar czvf npm-export.tar.gz -C /path/to/parent data letsencrypt`. Then `npm-migrate-import /tmp/npm-export.tar.gz` or `npm-migrate-import /tmp/npm-data/`. |
| **Northstar/AMI backup** | Archive created by `npm-backup` (contains `opt/npm/data/` and optionally `opt/npm/letsencrypt/`). | Transfer the `.tar.gz` to this instance and run `npm-migrate-import /path/to/npm-YYYYMMDDHHMMSS.tar.gz`. |
| **Other AMIs** | Same layout as DIY Docker if they use the standard NPM data paths. | Same as DIY Docker: copy the directory that contains `database.sqlite` (and sibling `letsencrypt` if present). |

---

## Reliability KPI Trend History

The `reliability-report` command now persists a KPI snapshot to `/var/lib/northstar/npm/reports/kpi-history.jsonl` each time it runs. The daily health-report timer chains a reliability-report run, building a rolling 90-day history.

View trend summaries:

```bash
sudo npm-helper reliability-report --history
sudo npm-helper reliability-report --history --json
```

The trend output shows 7-day and 30-day averages for backup success rate, restore verification pass rate, and rollback readiness -- designed for pasting into incident reviews or compliance evidence.

---

## Enterprise Support

This AMI is a **hardened, production-grade appliance** backed by Northstar Cloud Solutions. The support model below defines a clear standard operating procedure (SOP) to ensure fast, safe issue resolution.

### Support Tiers

| Tier | Scope | Response expectation | How to Access |
|------|--------|----------------------|---------------|
| **Self-Service / Community** | Documentation, troubleshooting guides, and CLI tooling (`npm-helper`, `northstar`) | No SLA | [`docs/`](./index.md), [`docs/troubleshooting.md`](./troubleshooting.md) |
| **Standard** *(optional)* | Best-effort email support for AMI initialization, backup/restore, and upgrade guidance | Best-effort response within N business days *(define in your contract)* | Email **support@northstarcloud.io** with support bundle; tier subject to availability |
| **Premium / Enterprise** *(optional)* | Dedicated support for credential recovery, upgrade failures, observability, and operational escalations | Response within M hours *(define in your contract)*; optional phone/video for critical issues | Email **support@northstarcloud.io** with support bundle; tier subject to availability |

Placeholder SLA values (N business days, M hours) are filled in when you have an active support agreement. The table above defines the support plan matrix and scope boundaries.

### Standard Operating Procedure (SOP)

Before contacting Premium Hardened Support, complete the following steps:

1. **Generate a support bundle:**

```bash
sudo npm-support-bundle
```

This produces an encrypted diagnostic archive at `/var/backups/npm-support-YYYYMMDDHHMMSS.tar.gz` containing system information, service status, sanitized logs, NPM data metadata, and backup configuration. **No secrets, passwords, or private keys are included.**

2. **Collect instance metadata:**

```bash
sudo npm-helper diagnostics --json > /tmp/npm-diagnostics.json
```

3. **Prepare your support request** with:
   - The support bundle archive path (or attach it directly)
   - The diagnostics JSON output
   - AWS region and instance type
   - AMI version (from `/opt/northstar/build-manifest.txt`)
   - A concise problem description: what you expected, what happened, when it started, and any recent changes

4. **Email support@northstarcloud.io** with the above information.

### What the support bundle contains

| Section | Contents | Sensitive Data |
|---|---|---|
| System information | OS version, kernel, uptime, disk/memory usage | No |
| Service status | Docker, NPM stack, CloudWatch agent, init services | No |
| Credential metadata | File location and existence (content is **not** included) | No |
| Logs | syslog, auth.log, cloud-init, journal (last 1000 lines) | Minimal (IP addresses, usernames in auth logs) |
| NPM data metadata | Directory listings and sizes (no database content) | No |
| Backup metadata | Backup config and archive file listing | No |

### What the support bundle does NOT contain

- Admin passwords or credentials file content
- TLS private keys or certificate files
- NPM database content
- AWS access keys or IAM credentials
- Docker image layers or application data

### Security guidance

- Review the bundle contents before sharing if your organization requires it.
- Support bundles are written with root ownership. Only `root` (or `sudo`) can read them.
- Do **not** include secrets, private keys, or full credentials in support emails or tickets.
- If your organization requires encrypted transport for diagnostic data, note that the bundle archive itself is a standard `.tar.gz`; apply GPG or your organization's encryption tooling before transmitting if required.
