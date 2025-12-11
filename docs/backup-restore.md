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
  Number of most recent local backup files to keep.
  If set to `7`, the script retains the 7 newest backups and deletes older ones.
  Set to `0` to disable automatic cleanup (not recommended).

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

Check status:

```bash
sudo systemctl status npm-backup.timer
sudo systemctl status npm-backup.service
```

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

> ⚠ Only run this when you are comfortable overwriting the current NPM data.

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

- Test `npm-restore` in a non-production environment, so you’re familiar with the flow before you need it in an emergency.
