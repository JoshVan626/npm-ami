# Troubleshooting

Common issues and how to debug them.

---

## First boot FAQ (Preflight / Init / Post-init)

The first boot flow is:

- `npm-preflight.service` (preflight checks)
- `npm-init.service` (one-time initialization)
- `npm-postinit.service` (post-init health summary)

Status is visible in:

- The SSH login banner (MOTD) under **Initialization Status**
- `sudo npm-helper status`
- Status files:
  - `/var/lib/northstar/npm/preflight-status`
  - `/var/lib/npm-init-complete` (marker file)
  - `/var/lib/northstar/npm/postinit-status`

### Preflight failures

Preflight checks for common blockers (disk space, Docker active, docker compose available, image pullability, directory permissions, required tools).

Commands:

```bash
sudo systemctl status npm-preflight --no-pager
sudo journalctl -u npm-preflight --no-pager -n 200
sudo npm-helper status
```

Most common causes:
- Insufficient disk space
- Docker inactive
- docker compose missing
- No outbound internet access (image pull fails)
- Permissions/ownership issues on `/opt/npm` or its subdirectories
- Missing `curl` on the host

### Init / post-init failures

`npm-init.service` generates the initial admin credentials once and writes a marker file. `npm-postinit.service` checks that the stack is running and the UI responds locally.

Commands:

```bash
sudo systemctl status npm-init npm-postinit npm --no-pager
sudo journalctl -u npm-init -n 200 --no-pager
sudo journalctl -u npm-postinit -n 200 --no-pager
sudo npm-helper diagnostics --json
```

Safe rerun guidance:
- `sudo systemctl start npm-preflight.service`
- `sudo systemctl start npm-init.service`
- `sudo systemctl start npm-postinit.service`

### Admin credential visibility and recovery

- Credentials are stored in a root-only file (see `docs/security.md`).
- `npm-helper show-admin` prints the username and file location.
- `npm-helper show-creds` prints the stored credentials (root only).
- If you want a fresh password, rotate credentials:
  - `sudo npm-helper rotate-admin`

### CloudWatch (IAM optional)

CloudWatch logs/metrics ship only when you attach an instance role/policy. Lack of IAM must not break the application.

Commands:

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
sudo journalctl -u amazon-cloudwatch-agent -n 200 --no-pager
```

## NPM admin UI is not reachable on port 81

Port 81 access has **two gates**:

- **Gate 1 – Security Group:** your EC2 security group must allow your source IP/CIDR to port `81/tcp` (never `0.0.0.0/0` for admin UI).
- **Gate 2 – Instance firewall:** UFW on the instance also restricts port 81; use `npm-helper admin-access` to allowlist your IP or fall back to an SSH tunnel.

1. Check security group:
   - Ensure `81/tcp` is allowed from your IP or CIDR (never open to the internet).

2. Check UFW on the instance:

   ```bash
   sudo ufw status numbered
   ```

   Make sure port 81 appears as allowed from your IP.

   To allowlist your IP using the helper (instance firewall gate):

   ```bash
   sudo npm-helper admin-access enable --cidr <your-ip>/32
   ```

3. Check services:

   ```bash
   sudo systemctl status docker
   sudo systemctl status npm
   ```

4. Check Docker containers:

   ```bash
   cd /opt/npm
   sudo docker compose ps
   ```

If the NPM container is not running, check logs:

```bash
cd /opt/npm
sudo docker compose logs
```

---

## I lost the admin password

You can always recover or reset it from the instance:

- Show current username:

  ```bash
  sudo npm-helper show-admin
  ```

- Show stored credentials (root only):

  ```bash
  sudo npm-helper show-creds
  ```

- Force a rotation (generates a new password):

  ```bash
  sudo npm-helper rotate-admin
  ```

For security, passwords are not printed on login. See `docs/security.md` for where the credentials are stored and how to handle them safely.

---

## Backups do not appear in S3

1. Check `/etc/npm-backup.conf`:

   - `s3_bucket` is set
   - `s3_prefix` is what you expect

2. Ensure the instance has an IAM role with permissions to write to the bucket.

3. Run:

   ```bash
   sudo npm-backup
   ```

4. Check the output for warnings.

5. Verify the S3 bucket in the AWS Console.

Remember: even if S3 upload fails, local backups are still created in
`local_backup_dir`.

---

## Backup verification or restore validation

If you want confidence in the latest backup or need to confirm an archive
before restore:

```bash
sudo npm-helper backup verify
sudo npm-helper restore --dry-run /var/backups/npm-YYYYMMDDHHMMSS.tar.gz
```

These checks are non-destructive and provide a quick sanity check.

---

## CloudWatch logs are missing

1. Check the agent service:

   ```bash
   sudo systemctl status amazon-cloudwatch-agent
   ```

2. Check journal:

   ```bash
   sudo journalctl -u amazon-cloudwatch-agent
   ```

3. Ensure the instance IAM role has permissions to write CloudWatch Logs.

4. In the AWS Console, navigate to:

   - CloudWatch → Logs → Log groups → `/northstar-cloud-solutions/npm`

If the agent is running but logs are missing, IAM permissions are the most common cause.

---

## Getting more help

Before opening a support request, run:

```bash
sudo npm-diagnostics
```

and include the output (or relevant parts) so we can help you more quickly.
