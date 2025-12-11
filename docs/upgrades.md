# Upgrades

This document explains how to think about upgrades for the AMI:

**Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions**

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

## 2. Upgrading to a newer AMI version

When Northstar Cloud Solutions releases a new version of the AMI (e.g., with updated NPM Docker image, security patches, or new features), you can upgrade by launching a new instance from the newer AMI and migrating your data.

### Recommended upgrade workflow

1. **Backup your current instance:**
   ```bash
   sudo npm-backup
   ```
   
   If you have S3 configured, the backup will be uploaded automatically. Otherwise, copy the backup file from `/var/backups/` to a safe location.

2. **Launch a new instance from the newer AMI:**
   - In AWS Console, select the latest AMI version
   - Use the same instance type (or upgrade if needed)
   - Configure security groups and networking as before

3. **Test the new instance:**
   - Verify the new instance boots correctly
   - Check that NPM admin UI is accessible
   - Confirm CloudWatch logs and metrics are working
   - Test basic functionality before migrating data

4. **Restore your data to the new instance:**
   ```bash
   # Copy backup file to new instance (via S3, scp, or other method)
   sudo npm-restore /path/to/npm-YYYYMMDDHHMMSS.tar.gz
   ```

5. **Verify everything works:**
   - Log into NPM admin UI
   - Check that all proxy hosts are present
   - Verify SSL certificates are intact
   - Test a few proxy hosts to ensure routing works

6. **Switch traffic (if applicable):**
   - Update DNS records to point to the new instance
   - Update load balancer targets
   - Monitor for any issues

7. **Keep old instance running temporarily:**
   - Don't terminate the old instance immediately
   - Keep it running for a few days as a rollback option
   - Once confident, terminate the old instance

### Rollback considerations

If something goes wrong with the new instance:

- The old instance is still running with your original data
- Simply point DNS/load balancer back to the old instance
- Investigate issues on the new instance without pressure
- Fix issues and try the upgrade again when ready

---

## 3. Updating NPM Docker image (advanced)

The AMI pins NPM to a specific, tested Docker image version for stability. However, you may want to manually update to a newer NPM version to get new features or security fixes.

> **Warning:** Updating the NPM Docker image manually is not officially supported. Test thoroughly in a non-production environment first. Some NPM versions may have breaking changes or require database migrations.

### When to consider manual updates

- You need a feature available in a newer NPM version
- A security vulnerability is patched in a newer version
- You're comfortable troubleshooting Docker and NPM issues

### How to update the NPM Docker image

1. **Backup first:**
   ```bash
   sudo npm-backup
   ```

2. **Edit the Docker Compose file:**
   ```bash
   sudo nano /opt/npm/docker-compose.yml
   ```
   
   Change the image tag, for example:
   ```yaml
   # From:
   image: "jc21/nginx-proxy-manager:2.13.5"
   
   # To:
   image: "jc21/nginx-proxy-manager:2.14.0"
   ```

3. **Pull the new image:**
   ```bash
   cd /opt/npm
   sudo docker compose pull
   ```

4. **Restart the stack:**
   ```bash
   sudo systemctl restart npm
   ```

5. **Verify everything works:**
   - Check NPM admin UI is accessible
   - Verify all proxy hosts are still configured
   - Test a few proxy hosts
   - Check CloudWatch logs for errors
   - Monitor for a few hours

6. **If something breaks:**
   - Restore from backup using `npm-restore`
   - Revert the `docker-compose.yml` change
   - Report the issue to support if needed

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
