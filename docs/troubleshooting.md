# Troubleshooting

Common issues and how to debug them.

---

## NPM admin UI is not reachable on port 81

1. Check security group:
   - Ensure `81/tcp` is allowed from your IP or CIDR.

2. Check UFW on the instance:

   ```bash
   sudo ufw status numbered
   ```

   Make sure port 81 appears as allowed.

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

- Show current credentials:

  ```bash
  sudo npm-helper show-admin
  ```

- Force a rotation (generates a new password and updates MOTD):

  ```bash
  sudo npm-helper rotate-admin
  ```

Then log in again with the new password.

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
