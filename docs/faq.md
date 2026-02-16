# Frequently Asked Questions

Common questions about the Nginx Proxy Manager (NPM) for AWS AMI by Northstar Cloud Solutions.

---

## Credentials and access

### How do I get the admin password?

Credentials are generated on first boot and stored in a root-only file. They are **not** printed in the login banner.

Run:

```bash
sudo npm-helper show-creds
```

You must be root (use `sudo`). See [Security](security.md) for details.

### I lost the admin password. How do I recover it?

If you have SSH access:

```bash
sudo npm-helper show-creds
```

To generate a new password:

```bash
sudo npm-helper rotate-admin
```

See [Troubleshooting – I lost the admin password](troubleshooting.md#i-lost-the-admin-password).

### Why can't I reach the admin UI on port 81?

Port 81 access has two gates:

1. **Security group** – Must allow `81/tcp` from your IP (never `0.0.0.0/0`)
2. **Instance firewall (UFW)** – Must allowlist your IP: `sudo npm-helper admin-access enable --cidr <your-ip>/32`

Alternatively, use an SSH tunnel:

```bash
ssh -i /path/to/key.pem -L 8181:localhost:81 ubuntu@<instance-ip>
```

Then open `http://localhost:8181`. See [Troubleshooting – NPM admin UI is not reachable](troubleshooting.md#npm-admin-ui-is-not-reachable-on-port-81).

---

## First boot

### How long does first boot take?

Usually **2–5 minutes** depending on instance size and image pull speed. The instance runs preflight checks, starts NPM, generates credentials, and performs post-init health checks.

### First boot seems stuck. What do I check?

1. Check status:
   ```bash
   sudo npm-helper status
   ```
2. Inspect the MOTD banner for **Initialization Status**
3. View logs:
   ```bash
   sudo journalctl -u npm-preflight -n 200 --no-pager
   sudo journalctl -u npm-init -n 200 --no-pager
   sudo journalctl -u npm-postinit -n 200 --no-pager
   ```

Common causes: insufficient disk space, Docker inactive, no outbound internet (image pull fails). See [Troubleshooting – First boot FAQ](troubleshooting.md#first-boot-faq-preflight--init--post-init).

### Can I rerun initialization?

Init is idempotent. You can safely rerun:

```bash
sudo systemctl start npm-preflight.service
sudo systemctl start npm-init.service
sudo systemctl start npm-postinit.service
```

---

## Backup and restore

### Are backups automatic?

Yes. A systemd timer runs `npm-backup` **daily at 02:00** (configurable). Backups are stored locally under `/var/backups` by default and optionally uploaded to S3 if configured in `/etc/npm-backup.conf`.

### How do I verify a backup?

```bash
sudo npm-helper backup verify
```

### How do I restore from a backup?

```bash
sudo npm-restore /var/backups/npm-YYYYMMDDHHMMSS.tar.gz
```

Or use the helper with dry-run first:

```bash
sudo npm-helper restore --dry-run /path/to/backup.tar.gz
sudo npm-helper restore /path/to/backup.tar.gz
```

See [Backup & Restore](backup-restore.md).

### Backups don't appear in S3

1. Check `/etc/npm-backup.conf` – `s3_bucket` must be set
2. Ensure the instance has an IAM role with `s3:PutObject` (and related) on the bucket
3. Run `sudo npm-backup` and check output for warnings

Local backups still succeed even if S3 upload fails. See [Troubleshooting – Backups do not appear in S3](troubleshooting.md#backups-do-not-appear-in-s3).

---

## Upgrades

### Should I upgrade in-place or launch a new AMI?

**Recommended:** Launch a new instance from the latest AMI and restore from backup. See [Upgrades – Recommended upgrade workflow](upgrades.md#2-upgrading-to-a-newer-ami-version).

**Optional in-place:** Use `sudo npm-helper upgrade` for NPM container updates. This is backup-first and supports rollback. See [Upgrades – Updating NPM Docker image](upgrades.md#3-updating-npm-docker-image-optional-in-place-patch-upgrade).

### Upgrade failed. How do I roll back?

```bash
sudo npm-helper rollback --dry-run   # preview
sudo npm-helper rollback             # execute
```

See [Upgrades](upgrades.md) for full guidance.

---

## CloudWatch and observability

### CloudWatch logs are missing

1. Attach an instance IAM role with CloudWatch Logs permissions
2. Check agent status: `sudo systemctl status amazon-cloudwatch-agent`
3. Check logs: `sudo journalctl -u amazon-cloudwatch-agent -n 200`

CloudWatch is optional; the application works without it. See [Troubleshooting – CloudWatch logs are missing](troubleshooting.md#cloudwatch-logs-are-missing).

### How do I enable the observability baseline (dashboard + alarms)?

```bash
sudo northstar observability enable
```

Requires IAM permissions and the AWS CLI. Optional SNS topic ARNs can be passed for alarm notifications.

---

## Getting more help

### What should I include when opening a support request?

Run and attach (or paste relevant output):

```bash
sudo npm-support-bundle
sudo npm-helper diagnostics --json
```

Include: AWS region, AMI version, problem description (expected vs actual), and recent changes. Do **not** include secrets. See the [Support](README.md#support) section in the main README.
