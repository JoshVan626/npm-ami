# Backup & Restore

Protecting your Nginx Proxy Manager data and TLS certificates is critical.
This AMI includes built-in backup and restore tooling.

---

## What gets backed up

The `npm-backup` script creates **timestamped archives** containing:

- `/opt/npm/data`
- `/opt/npm/letsencrypt`

Backups are:

- Stored locally under a configurable directory (default: `/var/backups`)
- Named like: `npm-YYYYMMDDHHMMSS.tar.gz`
- Optionally uploaded to S3

---

## Configuration: /etc/npm-backup.conf

Backup behavior is controlled by:

```bash
/etc/npm-backup.conf
```

The file is INI-style:

```ini
[backup]
local_backup_dir = /var/backups
s3_bucket =
s3_prefix = npm
local_retention = 7
```

Fields:

- `local_backup_dir`  
  Directory where backup archives are stored.

- `s3_bucket`  
  If set to a bucket name (e.g. `my-npm-backups`), backups are **also** uploaded
  to S3 via `aws s3 cp`. If empty, S3 upload is disabled.

- `s3_prefix`  
  Optional key prefix. Example: `npm` → backups stored under `npm/...` in S3.

- `local_retention`  
  Number of most recent local backup files to keep. **Must be 1 or greater.**
  If set to `7`, the script retains the 7 newest backups and deletes older ones.
  Setting this to `0` will cause `npm-backup` to fail with an error (to prevent
  unbounded disk growth). Recommended: `7` or higher.

---

## How backups are created

You can run a backup manually:

```bash
sudo npm-backup
```

This will:

1. Read `/etc/npm-backup.conf`
2. Create a `npm-*.tar.gz` archive under `local_backup_dir`
3. If `s3_bucket` is set:
   - Try to upload the archive to `s3://<bucket>/<prefix>/<file>`
   - Log a warning if S3 upload fails, but keep the local backup
4. Apply the retention policy to local backups

A systemd timer runs this **once per day at 02:00** by default:

- Service: `npm-backup.service`
- Timer: `npm-backup.timer`

Check timer status:

```bash
sudo systemctl status npm-backup.timer
sudo systemctl status npm-backup.service
```

---

## Checking backup status

The backup script writes status to sentinel files and can be checked via `npm-helper`:

```bash
sudo npm-helper status
```

This displays:

- **Last backup file**: Most recent archive in the backup directory
- **Last run**: Timestamp of the last backup attempt
- **Last success**: Timestamp and filename of the last successful backup
- **Last failure**: If present, timestamp and reason for the last failure

### Sentinel files

Backup status is stored in `/var/lib/northstar/npm/`:

| File | Description |
|------|-------------|
| `backup-last-run` | Timestamp of last backup start |
| `backup-last-success` | Timestamp + filename on success |
| `backup-last-failure` | Timestamp + reason on failure (cleared on success) |

You can also inspect these files directly:

```bash
cat /var/lib/northstar/npm/backup-last-success
cat /var/lib/northstar/npm/backup-last-failure
```

### Structured log output

Each backup run emits a single structured log line to stdout/journald:

- Success: `NORTHSTAR_BACKUP status=success path=/var/backups/npm-*.tar.gz duration_s=N`
- Failure: `NORTHSTAR_BACKUP status=failure reason=<short_reason> duration_s=N`

If CloudWatch Agent is configured, these lines flow to CloudWatch Logs via syslog.

---

## Enabling S3 backups

To enable S3 uploads:

1. Ensure the instance has IAM permissions to write to your bucket, e.g. attach a
   role with `s3:PutObject` and `s3:ListBucket` on the target bucket.
2. Edit `/etc/npm-backup.conf`:

   ```ini
   [backup]
   local_backup_dir = /var/backups
   s3_bucket = my-npm-backup-bucket
   s3_prefix = npm
   local_retention = 7
   ```

3. Run a manual backup to test:

   ```bash
   sudo npm-backup
   ```

4. Verify the object appears in S3 under the configured bucket and prefix.

If S3 upload fails, the script will:

- Print a warning
- Still keep the local backup file

---

## Restore from a backup archive

Use `npm-restore` to restore from a backup archive.

> ⚠ **Only run this when you are comfortable overwriting the current NPM data.**

### Trust model

**Only restore archives created by `npm-backup` on trusted instances.**

The restore script validates archive contents before extraction and will refuse
to extract archives containing paths outside the expected directories
(`opt/npm/data`, `opt/npm/letsencrypt`). This security check prevents malicious
or corrupted archives from overwriting system files like `/etc/passwd`.

If validation fails, you'll see:

```
✗ Error: Archive contains paths outside allowed directories!
```

Do not attempt to bypass this check. The archive may be corrupted, tampered
with, or created by a different tool.

1. List available backups:

   ```bash
   ls -1 /var/backups/npm-*.tar.gz
   ```

2. Run restore:

   ```bash
   sudo npm-restore /var/backups/npm-YYYYMMDDHHMMSS.tar.gz
   ```

What `npm-restore` does:

1. Stop the `npm` systemd service.
2. Move existing `/opt/npm/data` and `/opt/npm/letsencrypt` to `.bak-<timestamp>`
   safety backups (if they exist and are non-empty).
3. Extract the archive from `/` so the original paths are restored.
4. Fix ownership on the restored directories.
5. Start the `npm` service.
6. Perform a health check against `http://localhost:81/api`.

If the health check fails:

- The script **does not** automatically roll back.
- It prints clear instructions and tells you where the `.bak-` safety directories are, so you can manually restore them.

---

## Best practices

- Keep `local_retention` at least `5–7` for a buffer of good backups.
- Use S3 uploads in combination with IAM roles for off-instance copies.
- After any major configuration change, you can force a backup:

  ```bash
  sudo npm-backup
  ```

- Test `npm-restore` in a non-production environment, so you're familiar with the flow before you need it in an emergency.

---

## Troubleshooting backup failures

If backups are failing, check the last failure reason:

```bash
cat /var/lib/northstar/npm/backup-last-failure
```

Or use `npm-helper status` to see the full backup status.

### Common failure reasons

| Reason | Cause | Fix |
|--------|-------|-----|
| `concurrent_run_in_progress` | Another backup is still running | Wait for it to finish, or check for stuck processes |
| `invalid_retention_value` | `local_retention` in config is less than 1 | Set `local_retention = 7` (or higher) in `/etc/npm-backup.conf` |
| `cannot_create_backup_dir` | Backup directory path is invalid or permissions issue | Verify `local_backup_dir` path exists and is writable |
| `backup_dir_not_writable` | No write permission to backup directory | Check permissions: `ls -la /var/backups` |
| `tar_archive_failed` | Failed to create the tar archive | Check disk space: `df -h /var/backups` |
| `backup_file_not_created` | Archive creation succeeded but file not found | Check disk space and filesystem errors |

### S3 upload failures

S3 upload failures do **not** fail the backup—the local backup is still created. Common S3 issues:

- **No IAM role attached**: The instance needs an IAM role with `s3:PutObject` permission
- **Bucket doesn't exist**: Verify the bucket name in `/etc/npm-backup.conf`
- **Wrong region**: The bucket must be accessible from the instance's region
- **AWS CLI not installed**: Check with `which aws`

To test S3 permissions manually:

```bash
# Create a test file
echo "test" > /tmp/s3-test.txt

# Try to upload (replace with your bucket)
aws s3 cp /tmp/s3-test.txt s3://YOUR-BUCKET/test.txt

# Clean up
rm /tmp/s3-test.txt
aws s3 rm s3://YOUR-BUCKET/test.txt
```

### Viewing backup logs

Backup output goes to journald:

```bash
# Last backup run
sudo journalctl -u npm-backup.service -n 50

# Search for structured log lines
sudo journalctl -u npm-backup.service | grep NORTHSTAR_BACKUP
```
