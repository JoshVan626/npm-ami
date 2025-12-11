# Testing Checklist

This checklist ensures the AMI is fully functional and ready for use before publishing to AWS Marketplace.

**Product:** Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions

---

## Pre-Build Validation

Before running the build scripts, verify the repository is complete:

- [ ] All files in `ami-files/` are present
- [ ] All scripts in `scripts/` are present (00-05)
- [ ] All documentation files exist
- [ ] Scripts have executable permissions (chmod +x)
- [ ] Python scripts have valid syntax (no syntax errors)
- [ ] Bash scripts have valid syntax (run `bash -n script.sh` on each)
- [ ] JSON files are valid (CloudWatch config, etc.)
- [ ] YAML files are valid (docker-compose.yml)
- [ ] INI files are valid (npm-backup.conf)
- [ ] No placeholder text like `[BrandName]` remains
- [ ] All documentation URLs point to correct locations

### Quick validation commands:

```bash
# Check script syntax
for script in scripts/*.sh; do bash -n "$script" || echo "Error in $script"; done

# Check Python syntax
python3 -m py_compile ami-files/usr-local-bin/*.py

# Validate JSON
python3 -m json.tool ami-files/opt-aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json > /dev/null

# Validate YAML (if yq or similar is available)
# docker compose -f ami-files/opt-npm/docker-compose.yml config > /dev/null
```

---

## Build Process Validation

Run each script in order on a fresh Ubuntu 22.04 EC2 instance and verify:

### Script 00: Base Packages

- [ ] Script runs without errors
- [ ] All base packages install successfully
- [ ] Python 3 and pip are installed
- [ ] bcrypt Python package is installed (via apt or pip)
- [ ] AWS CLI is installed
- [ ] unattended-upgrades is configured
- [ ] No package installation failures

### Script 01: Docker Installation

- [ ] Script runs without errors
- [ ] Docker Engine installs successfully
- [ ] Docker Compose plugin installs successfully
- [ ] Docker service starts and is active
- [ ] `docker --version` works
- [ ] `docker compose version` works
- [ ] `ubuntu` user is added to `docker` group (if user exists)

### Script 02: NPM Stack Setup

- [ ] Script runs without errors
- [ ] All directories are created (`/opt/npm`, `/opt/npm/data`, `/opt/npm/letsencrypt`)
- [ ] `docker-compose.yml` is copied to `/opt/npm/`
- [ ] All Python scripts are copied to `/usr/local/bin/` with correct permissions (0755)
- [ ] All bash scripts are copied to `/usr/local/bin/` with correct permissions (0755)
- [ ] `npm-backup.conf` is copied to `/etc/`
- [ ] All systemd units are copied to `/etc/systemd/system/`
- [ ] Systemd daemon is reloaded
- [ ] `npm.service` is enabled
- [ ] `npm-init.service` is enabled
- [ ] `npm-backup.timer` is enabled

### Script 03: Security Hardening

- [ ] Script runs without errors
- [ ] Fail2ban config is copied to `/etc/fail2ban/jail.local`
- [ ] Sysctl config is copied to `/etc/sysctl.d/99-brand-hardened.conf`
- [ ] SSH banner (`issue.net`) is copied to `/etc/issue.net`
- [ ] SSH config is hardened:
  - [ ] `PasswordAuthentication no` is set
  - [ ] `PermitRootLogin no` is set
  - [ ] `UsePAM yes` is set
  - [ ] `Banner /etc/issue.net` is set
- [ ] Sysctl settings are applied
- [ ] UFW is configured and enabled:
  - [ ] Port 22/tcp allowed
  - [ ] Port 80/tcp allowed
  - [ ] Port 81/tcp allowed
  - [ ] Port 443/tcp allowed
- [ ] Fail2ban service is enabled and active
- [ ] SSH host keys are removed (for AMI build)
- [ ] SSH service reloads/restarts successfully

### Script 04: CloudWatch Setup

- [ ] Script runs without errors
- [ ] CloudWatch Agent installs (via apt or .deb download)
- [ ] Config file is copied to `/opt/aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json`
- [ ] CloudWatch Agent service is enabled
- [ ] CloudWatch Agent service starts successfully
- [ ] Service is active after a few seconds

### Script 05: Cleanup for AMI

- [ ] Script runs without errors (with confirmation)
- [ ] Services stop successfully (npm, docker, cloudwatch-agent)
- [ ] Apt caches are cleaned
- [ ] Log files are truncated
- [ ] Cloud-init instance data is removed
- [ ] Machine-id is reset
- [ ] Bash history is cleared
- [ ] Temporary files are removed
- [ ] SSH host keys are removed
- [ ] Sanity checks pass (key directories exist)

---

## First Boot Validation

After creating the AMI and launching a new instance from it:

### Instance Boot

- [ ] Instance boots successfully
- [ ] No boot errors in system logs
- [ ] Cloud-init completes successfully

### Service Startup

- [ ] `docker.service` is active
- [ ] `npm.service` is active
- [ ] `npm-init.service` runs and completes (one-time)
- [ ] `npm-backup.timer` is active
- [ ] `amazon-cloudwatch-agent.service` is active
- [ ] `fail2ban.service` is active

### NPM Container

- [ ] NPM container is running (`docker ps` shows container)
- [ ] Container is healthy (no restart loops)
- [ ] Container logs show no critical errors
- [ ] Ports 80, 81, 443 are listening

### First Boot Initialization

- [ ] `/var/lib/npm-init-complete` marker file exists
- [ ] `/root/npm-admin-credentials.txt` exists with credentials
- [ ] MOTD script `/etc/update-motd.d/50-npm-info` exists
- [ ] MOTD displays on SSH login with:
  - [ ] Product name
  - [ ] Admin URL (with IP address)
  - [ ] Username
  - [ ] Password
  - [ ] Onboarding checklist

### SSH Access

- [ ] Can SSH into instance with key (not password)
- [ ] Password authentication is rejected
- [ ] Root login is rejected
- [ ] SSH banner (`/etc/issue.net`) displays
- [ ] SSH host keys are unique (not reused from AMI)

---

## Functional Validation

### NPM Admin UI

- [ ] Can access `http://<instance-ip>:81` in browser
- [ ] Login page loads
- [ ] Can log in with credentials from MOTD/credentials file
- [ ] Admin dashboard loads after login
- [ ] No JavaScript errors in browser console

### NPM Functionality

- [ ] Can create a new Proxy Host
- [ ] Proxy Host configuration saves
- [ ] Can enable SSL/Let's Encrypt (test with valid domain if available)
- [ ] Existing proxy hosts (if restored from backup) work correctly

### CLI Tools

- [ ] `npm-helper show-admin` displays credentials
- [ ] `npm-helper status` shows service and container status
- [ ] `npm-helper rotate-admin` generates new password and updates:
  - [ ] NPM database
  - [ ] Credentials file
  - [ ] MOTD script
- [ ] `npm-diagnostics` runs and collects information
- [ ] `npm-support-bundle` creates a support bundle archive

### Backup & Restore

- [ ] `npm-backup` creates a backup archive in `/var/backups/`
- [ ] Backup file is valid tar.gz
- [ ] Backup contains `/opt/npm/data` and `/opt/npm/letsencrypt`
- [ ] If S3 is configured, backup uploads to S3 (or fails gracefully)
- [ ] Local retention policy works (keeps N most recent)
- [ ] `npm-restore` restores from backup:
  - [ ] Stops NPM stack
  - [ ] Creates safety backup
  - [ ] Extracts archive
  - [ ] Starts NPM stack
  - [ ] Health check passes
  - [ ] Restored data is accessible in NPM UI

### CloudWatch Integration

- [ ] CloudWatch Agent is running (`systemctl status amazon-cloudwatch-agent`)
- [ ] Logs appear in CloudWatch Logs:
  - [ ] Log group `/Northstar/npm` exists
  - [ ] Log stream `{instance_id}-syslog` has entries
  - [ ] Log stream `{instance_id}-auth` has entries
- [ ] Metrics appear in CloudWatch Metrics:
  - [ ] Namespace `Northstar/System` exists
  - [ ] Metric `mem_used_percent` has data points
  - [ ] Metric `disk.used_percent` has data points
  - [ ] Dimensions include `InstanceId` and `InstanceType`

---

## Security Validation

### SSH Security

- [ ] Password authentication is disabled (attempt fails)
- [ ] Root login is disabled (attempt fails)
- [ ] Only key-based authentication works
- [ ] SSH banner displays correctly

### Firewall (UFW)

- [ ] UFW is enabled (`ufw status` shows "Status: active")
- [ ] Only required ports are open:
  - [ ] 22/tcp (SSH)
  - [ ] 80/tcp (HTTP)
  - [ ] 81/tcp (NPM Admin)
  - [ ] 443/tcp (HTTPS)
- [ ] Other ports are blocked (test with `nc` or similar)

### Fail2ban

- [ ] Fail2ban service is active
- [ ] SSH jail is enabled (`fail2ban-client status sshd`)
- [ ] Fail2ban monitors `/var/log/auth.log`

### Sysctl Hardening

- [ ] Sysctl settings are applied:
  ```bash
  sysctl net.ipv4.conf.all.accept_redirects  # Should be 0
  sysctl net.ipv4.conf.all.send_redirects   # Should be 0
  sysctl net.ipv4.conf.all.accept_source_route  # Should be 0
  sysctl net.ipv4.icmp_echo_ignore_broadcasts  # Should be 1
  sysctl net.ipv4.conf.all.rp_filter  # Should be 1
  ```

### Instance Identity

- [ ] Each instance has unique SSH host keys (compare with another instance)
- [ ] Machine ID is unique per instance (`/etc/machine-id`)

---

## AMI Snapshot Validation

After running cleanup and creating the AMI:

### Cleanup Verification

- [ ] Cleanup script completed successfully
- [ ] No instance-specific data remains:
  - [ ] No cloud-init instance data
  - [ ] No SSH host keys
  - [ ] No machine-id (truncated)
  - [ ] No bash history
  - [ ] Logs are cleared

### AMI Launch Test

- [ ] Can launch new instance from AMI
- [ ] New instance boots successfully
- [ ] First boot initialization runs on new instance
- [ ] New instance gets unique SSH host keys
- [ ] New instance gets unique machine-id
- [ ] New instance generates unique admin password
- [ ] No data from builder instance carries over

### Multiple Instance Test

- [ ] Launch 2-3 instances from the same AMI
- [ ] Each instance has unique credentials
- [ ] Each instance has unique SSH host keys
- [ ] Instances don't interfere with each other
- [ ] All instances function independently

---

## Performance & Resource Validation

- [ ] Instance boots in reasonable time (< 5 minutes for first boot)
- [ ] NPM container starts within 2-3 minutes
- [ ] Memory usage is reasonable (check with `free -h`)
- [ ] Disk usage is reasonable (check with `df -h`)
- [ ] No excessive CPU usage at idle
- [ ] CloudWatch metrics show normal resource usage

---

## Documentation Validation

- [ ] All documentation links work
- [ ] Documentation matches actual behavior
- [ ] Examples in documentation are accurate
- [ ] No broken references
- [ ] Product name is consistent throughout

---

## Final Checklist

Before considering the AMI ready:

- [ ] All items in this checklist are verified
- [ ] No critical errors in logs
- [ ] All core functionality works
- [ ] Security hardening is effective
- [ ] Documentation is complete and accurate
- [ ] AMI can be launched and used successfully
- [ ] Multiple instances from same AMI work independently

---

## Notes

- Test on different instance types (t3.micro, t3.small, t3.medium)
- Test in different AWS regions if possible
- Keep test instances running for 24-48 hours to catch any delayed issues
- Monitor CloudWatch logs and metrics during extended testing
- Document any issues found and their resolutions

---

## Issue Tracking

If issues are found during testing:

1. Document the issue clearly
2. Note which checklist item failed
3. Identify root cause
4. Fix the issue
5. Re-test the specific item
6. Re-run full checklist if issue was critical



