# Upgrades

This document explains how to think about upgrades for the AMI:

**Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring by Northstar Cloud Solutions**

The design philosophy is **stability first**:

- The base OS is a hardened Ubuntu 22.04 image.

- Nginx Proxy Manager is pinned to a specific, tested Docker image tag.

- You choose when to upgrade instead of things changing underneath you.

---

## 1. OS & package updates

The underlying OS is **Ubuntu 22.04**.

Security updates are handled by `unattended-upgrades`, but you can still run
manual updates when needed:

```bash
sudo apt-get update
sudo apt-get upgrade
```

---

## 2. Upgrading to a newer AMI version (recommended: blue/green)

When Northstar Cloud Solutions releases a new version of the AMI (e.g., with updated NPM Docker image, security patches, or new features), the **recommended** approach is an immutable blue/green replacement: launch a new instance from the newer AMI, restore data, verify, and cut over traffic.

### Automated upgrade assistant

The `npm-upgrade-ami` command automates the preparation phase and generates a step-by-step checklist with copy-paste commands:

```bash
sudo npm-upgrade-ami
sudo npm-upgrade-ami --checklist-file /tmp/upgrade-checklist.txt
```

Or via the wrapper:

```bash
sudo northstar upgrade-ami
```

This ensures a fresh backup exists, collects instance metadata, and generates commands for launching the replacement, restoring data, verifying health, cutting over traffic, and decommissioning the old instance.

### Manual upgrade workflow

If you prefer to do it manually:

1. **Backup your current instance:**

```bash
sudo npm-backup
```

If you have S3 configured, the backup will be uploaded automatically. Otherwise, copy the backup file from `/var/backups/` to a safe location.

2. **Launch a new instance from the newer AMI:**
   - Use the Terraform/CloudFormation templates in `deploy/`, or launch manually via the AWS Console
   - Use the same instance type (or upgrade if needed)
   - Configure security groups and networking as before

3. **Wait for first-boot initialization and verify:**

```bash
sudo npm-helper status
```

4. **Restore your data to the new instance:**

```bash
sudo npm-restore /path/to/npm-YYYYMMDDHHMMSS.tar.gz
```

5. **Verify everything works:**

```bash
sudo npm-helper health-report
sudo npm-helper compliance-report
```

Also log into the NPM admin UI and check that all proxy hosts and certificates are present.

6. **Switch traffic:**
   - **Elastic IP:** Use the scripted cutover helper (from any host with AWS CLI):
     ```bash
     northstar cutover-eip <eip-allocation-id> <new-instance-id> --region <region> [--yes]
     ```
     Or: `npm-cutover-eip <eip-allocation-id> <new-instance-id> --region <region> [--yes]`
   - **DNS:** Update your DNS A record to point to the new instance's IP address

7. **Keep old instance running temporarily:**
   - Don't terminate the old instance immediately
   - Keep it stopped for a few days as a rollback option
   - Once confident, terminate the old instance

### Rollback considerations

If something goes wrong with the new instance:

- The old instance is still running with your original data
- Simply point DNS/load balancer back to the old instance
- Investigate issues on the new instance without pressure
- Fix issues and try the upgrade again when ready

### Compatibility matrix reference

Before planning in-place upgrades, check the AMI/NPM compatibility table in:

- `RELEASES.md` under **Compatibility Matrix**

---

## 3. Updating NPM Docker image (optional in-place patch upgrade)

The AMI pins NPM to a specific, tested Docker image tag for stability. The recommended approach is to upgrade by launching a newer AMI version and restoring from backup. If you choose to update NPM in-place, you are choosing to deviate from the pinned version promise and assume the operational risk.

> **Warning:** In-place NPM image updates are optional and not automatic. Test in a non-production environment first.

### When to consider manual updates

- You need a feature available in a newer NPM version
- A security vulnerability is patched in a newer version
- You're comfortable troubleshooting Docker and NPM issues

### Supported in-place workflow (backup-first helper)

1. **Backup + metadata first (recommended helper path):**
   ```bash
   sudo npm-helper upgrade --dry-run
   ```

2. **Run backup-first upgrade flow:**
   ```bash
   sudo npm-helper upgrade
   ```

3. **Optional automatic rollback on health failure:**
   ```bash
   sudo npm-helper upgrade --auto-rollback
   ```

4. **If you need to set a specific NPM image tag:**
   ```bash
   sudo npm-update-container <new_tag>
   ```

`npm-update-container` runs a **pre-upgrade compatibility check** (current image, DB integrity, proxy/cert counts, cert expiry) before proceeding. If the check reports warnings (e.g. cert expiring in under 7 days), the command exits unless you pass `--force`. It then enforces a safety backup, updates the compose image tag, recreates containers, performs a local health check, and attempts rollback if the new stack is unhealthy.

5. **Verify everything works:**
   - Check NPM admin UI is accessible
   - Verify all proxy hosts are still configured
   - Test critical proxy routes and TLS endpoints
   - Monitor logs for at least one backup cycle

### Rollback (revert the pinned tag)

If something breaks after an in-place update:

1. Restore from a known-good backup archive:
   ```bash
   sudo npm-helper restore /var/backups/npm-YYYYMMDDHHMMSS.tar.gz
   ```
2. If needed, revert to a known-good tag explicitly:
   ```bash
   sudo npm-update-container <known_good_tag>
   ```
3. Re-run status and health checks:
   ```bash
   sudo npm-helper status
   ```

### Automated rollback command

If an upgrade fails health checks and you did not run with `--auto-rollback`, run:

```bash
sudo npm-helper rollback --dry-run
sudo npm-helper rollback
```

Rollback behavior:

- Restores image tag from last captured metadata.
- Restores NPM data from the pre-upgrade backup archive.
- Re-runs health checks (container state + HTTP checks on `:81` and `/api`).
- Never deletes backup archives.

### Version channels (stable vs edge)

You can switch between two channels without specifying a tag:

| Channel | Description |
|---------|-------------|
| **stable** | Pinned, tested tag (default; e.g. `2.13.5`). Recommended for production. |
| **edge** | Latest upstream tag. Use only if you need bleeding-edge features and accept the risk. |

Switch channels:

```bash
sudo npm-helper set-channel stable
sudo npm-helper set-channel edge
```

Or via the wrapper:

```bash
sudo northstar set-channel stable
sudo northstar set-channel edge
```

`set-channel` reads `/etc/northstar/npm-image.conf` for `stable_tag` and `edge_tag`, then runs `npm-update-container <tag>` (backup-first, with health check and rollback on failure). To customize the tags:

```ini
# /etc/northstar/npm-image.conf
[channel]
channel = stable
stable_tag = 2.13.5
edge_tag = latest
```

### Staying on the pinned version

The AMI's pinned version is tested and known to work. For production stability, consider:

- Waiting for the next AMI release that includes the newer NPM version
- Testing newer versions in a separate test instance first
- Contacting support if you need a specific NPM version

---

## 4. Best practices

### Always backup before upgrades

Whether upgrading the AMI or manually updating NPM:

- Create a backup using `npm-backup`
- Verify the backup file exists and is not corrupted
- Store backups in S3 or another safe location
- Keep multiple backup generations

### Test in non-production first

- Launch a test instance from the new AMI
- Restore a copy of your production backup to the test instance
- Verify all functionality works
- Only upgrade production after successful testing

### Monitor after upgrades

- Check CloudWatch logs for errors
- Monitor CloudWatch metrics for unusual patterns
- Test all critical proxy hosts
- Verify SSL certificates are still valid
- Check that backups continue to work

### When to contact support

Contact Northstar Cloud Solutions support if:

- The upgrade process fails unexpectedly
- Data is lost during migration
- NPM becomes inaccessible after upgrade
- You encounter errors not covered in this documentation
- You need guidance on a specific upgrade scenario

### Upgrade timing

- Plan upgrades during maintenance windows
- Avoid upgrading during peak traffic periods
- Have a rollback plan ready
- Communicate with your team about the upgrade schedule
