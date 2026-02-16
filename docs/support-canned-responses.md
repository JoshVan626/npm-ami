# Support Canned Responses

> **Internal use for support staff.** Do not publish to customer-facing docs.

Templates for common support scenarios. Customize as needed.

---

## First-boot failure (preflight / init / post-init)

**Subject:** First boot / initialization issue – troubleshooting steps

Thank you for reaching out. To help us diagnose the initialization issue, please run the following and share the output:

1. **Check status:**
   ```bash
   sudo npm-helper status
   sudo npm-helper diagnostics --json
   ```

2. **Check preflight/init/post-init logs:**
   ```bash
   sudo journalctl -u npm-preflight -n 200 --no-pager
   sudo journalctl -u npm-init -n 200 --no-pager
   sudo journalctl -u npm-postinit -n 200 --no-pager
   ```

3. **Create a support bundle:**
   ```bash
   sudo npm-support-bundle
   ```

Most first-boot failures are due to: insufficient disk space (minimum ~4 GB free on `/`), Docker not active, no outbound internet (image pull fails), or permissions on `/opt/npm`. Please also confirm your instance type (e.g., t3.small) and that you waited 2–5 minutes for initialization to complete.

---

## Port 81 not reachable

**Subject:** Admin UI not reachable – port 81 access checklist

Thank you for contacting us. Port 81 access is controlled by two gates:

**1. EC2 Security Group** – Your security group must allow inbound `81/tcp` from your source IP or CIDR. It should *not* be open to `0.0.0.0/0`.

**2. Instance firewall (UFW)** – Run this on the instance to allowlist your IP:
```bash
sudo npm-helper admin-access enable --cidr <your-public-ip>/32
```

Replace `<your-public-ip>` with your current public IP.

**Alternative:** Use an SSH tunnel so port 81 doesn’t need to be open in the security group:
```bash
ssh -i /path/to/key.pem -L 8181:localhost:81 ubuntu@<instance-ip>
```
Then open `http://localhost:8181` in your browser.

Please confirm both gates are configured and try again. If the issue persists, run `sudo npm-support-bundle` and `sudo npm-helper diagnostics --json` and share the output.

---

## Upgrade failed / rollback guidance

**Subject:** Upgrade failed – rollback and recovery

If the upgrade failed health checks, you can roll back to the last-known-good state:

```bash
sudo npm-helper rollback --dry-run   # preview
sudo npm-helper rollback             # execute
```

The rollback restores the previous NPM image and data from the pre-upgrade backup. If you ran `npm-helper upgrade` with `--auto-rollback`, this may have run automatically.

If rollback metadata is missing or rollback fails, you can manually restore from a backup archive:

```bash
sudo npm-helper restore /var/backups/npm-YYYYMMDDHHMMSS.tar.gz
```

Replace with the timestamp of your last good backup. List backups with: `ls -1t /var/backups/npm-*.tar.gz`

Please share the output of `sudo npm-helper diagnostics --json` and any error messages if the rollback does not succeed.

---

## Credential recovery

**Subject:** Admin credentials – recovery steps

You can retrieve or reset the admin password from the instance:

**Retrieve existing credentials:**
```bash
sudo npm-helper show-creds
```

**Rotate to a new password:**
```bash
sudo npm-helper rotate-admin
```

Credentials are stored in a root-only file and are never printed in the MOTD. You must use `sudo` to run these commands.

If you no longer have SSH access, you’ll need to use EC2 serial console or recovery procedures for your setup (e.g., attaching the volume to another instance) to regain access before running these commands.

---

## Request for support bundle and diagnostics

**Subject:** Support request – please provide diagnostics

To help us troubleshoot, please run the following on the affected instance and attach the outputs (or paste relevant excerpts):

```bash
sudo npm-support-bundle
sudo npm-helper diagnostics --json
```

The support bundle is written under `/var/backups/` (e.g., `npm-support-YYYYMMDDHHMMSS.tar.gz`). Please review its contents before sharing and remove any sensitive data if needed.

Also include:
- AWS region and instance type
- AMI version (if known)
- A brief description: what you expected, what actually happened, when it started, and any recent changes (upgrades, config changes, etc.)

Do not include passwords, private keys, or other secrets in your response.
