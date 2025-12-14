# Operations

This AMI includes a few opinionated tools and services to make NPM easier to
run in production.

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
4. Write credentials to `/root/npm-admin-credentials.txt`
5. Update the SSH login banner (MOTD)

The wait time accounts for slow instance types or cold container pulls.

### Admin email

The default admin email is `admin@example.com` (NPM's default).

To use a different email, set the `NPM_ADMIN_EMAIL` environment variable before
first boot. For example, add to `/etc/environment`:

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

## CLI: npm-helper

`npm-helper` is installed under `/usr/local/bin`. It provides three main
subcommands:

### Show current admin credentials

```bash
sudo npm-helper show-admin
```

Outputs the current admin username/password stored in:

- `/root/npm-admin-credentials.txt`

### Rotate admin password

```bash
sudo npm-helper rotate-admin
```

What it does:

1. Waits for the NPM SQLite database to be ready.
2. Generates a new strong random password.
3. Updates the NPM `auth` table with the new bcrypt hash.
4. Writes the new credentials to `/root/npm-admin-credentials.txt`.
5. Updates the MOTD banner so new logins see the updated credentials.

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
- Last backup timestamp found under `/var/backups`

This is a quick way to check if the system is healthy.

---

## Logs & CloudWatch

The CloudWatch Agent is configured to ship:

- `/var/log/syslog`
- `/var/log/auth.log`

into a log group named:

```text
/northstar-cloud-solutions/npm
```

with per-instance log streams (e.g. `{instance_id}-syslog`, `{instance_id}-auth`).

You can view these in:

- AWS Console → CloudWatch → Logs → Log groups → `/northstar-cloud-solutions/npm`

This is useful for:

- SSH login attempts
- System service failures
- General OS-level troubleshooting

---

## Where NPM keeps its data

NPM runs in Docker and stores its state in:

- `/opt/npm/data` – configuration, SQLite DB
- `/opt/npm/letsencrypt` – TLS certificates

These paths are:

- Mounted into the NPM container
- Included in backup archives (`npm-backup` / `npm-restore`)
- Preserved across instance reboots

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

See [Backup & Restore](./backup-restore.md) for full configuration details.

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
