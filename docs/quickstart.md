# Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring

**by Northstar Cloud Solutions**

This guide walks you from **nothing** to a working Nginx Proxy Manager admin
panel on AWS using the Nginx Proxy Manager (NPM) for AWS AMI by Northstar Cloud Solutions.

> Assumes: you’re familiar with launching EC2 instances and security groups.

This is a server-only AMI (no desktop GUI). Use SSH or EC2 Instance Connect for access and administration.

---

## 1. Launch the EC2 instance

1. In the AWS Console, go to **EC2 → AMIs**.
2. Select the **Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring** AMI.
3. Click **Launch instance**.
4. Choose an instance type:
   - For testing: `t3.micro` / `t3.small`
   - For light production: `t3.medium` or higher (depending on traffic)
5. Select / create a key pair.
6. Configure **network and security group** to allow:
   - `22/tcp` – SSH (restricted to your admin IP)
   - `80/tcp` – HTTP
   - `443/tcp` – HTTPS
   - `81/tcp` – NPM admin UI (**do not** make public; allowlist your IP or use an SSH tunnel)
7. Launch the instance.

---

## Expected first boot timeline (2–5 minutes)

On first boot, the instance initializes NPM, generates admin credentials, and starts the stack. This usually completes in **2–5 minutes** depending on instance size and image pull speed.

---

## 2. First SSH login & credentials

Once the instance is running:

1. SSH in as `ubuntu`:

   ```bash
   ssh -i /path/to/key.pem ubuntu@<instance-public-ip>
   ```

2. On login, you will see a **MOTD banner** similar to:

  ```text
  Nginx Proxy Manager (NPM) for AWS by Northstar Cloud Solutions

   Admin URL: http://<instance-ip>:81
   Username: admin@example.com
   NPM initialized: credentials stored at /root/.northstar/npm-admin-credentials
   Run: sudo npm-helper show-creds
   ```

3. Credentials are **not printed in MOTD**. Retrieve them with:

   ```bash
   sudo npm-helper show-creds
   ```

   This command is **root-only** (use `sudo`).

   If you need to rotate credentials later, see **Security** (`docs/security.md`) and use `sudo npm-helper rotate-admin`.

   Use `northstar` (recommended) or `npm-helper` directly for admin commands.

---

## Day 0 checklist (tight, repeatable flow)

1. Wait **2–5 minutes** for first boot initialization.
2. Connect via SSH or EC2 Instance Connect (browser terminal).
3. Run: `sudo npm-helper status`
4. Run: `sudo npm-helper show-creds --yes`
5. Access the Admin UI safely (allowlist your IP or use an SSH tunnel; **do not** expose port 81 publicly).
6. Optional validation:
   - `sudo npm-helper backup verify`
   - `sudo npm-helper cert-check`
   - `sudo npm-helper upgrade --dry-run`

---

## 3. Log into Nginx Proxy Manager

1. Open your browser to (after allowlisting your IP or establishing an SSH tunnel):

   ```text
   http://<instance-public-ip>:81
   ```

2. Log in with the **username and password** from the credentials file.
3. You’re now in the NPM admin interface.

**Secure admin plane tip:** Do not expose port `81` to the internet. Use an SSH tunnel or allowlist a single trusted IP temporarily:

```bash
sudo npm-helper admin-access enable --cidr <your-ip>/32
```

---

## CloudWatch (Optional)

CloudWatch logs and metrics are optional and only ship if you attach an instance role/policy. Lack of IAM permissions should not break the application.

Check agent status:

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
sudo journalctl -u amazon-cloudwatch-agent -n 200 --no-pager
```

## Logging disclosure (CloudWatch optional)

When an instance role is attached, the CloudWatch agent can ship:

- `/var/log/syslog`
- `/var/log/auth.log`
- Docker container logs (`/var/lib/docker/containers/*/*-json.log`)
- Basic system metrics (CPU, memory, disk, network)

To disable CloudWatch shipping:

```bash
sudo systemctl disable --now amazon-cloudwatch-agent.service
```

## 4. Create your first proxy host

Inside NPM:

1. Go to **Hosts → Proxy Hosts → Add Proxy Host**.
2. Set:
   - **Domain Names**: `app.example.com`
   - **Scheme**: `http`
   - **Forward Hostname / IP**: internal app address (e.g., `10.0.1.23` or another EC2 instance)
   - **Forward Port**: `3000` (for example)
3. (Optional) Enable **SSL** and use Let’s Encrypt once DNS is pointing at the instance.
4. Save.

Once DNS is configured and propagated, `https://app.example.com` will route through this NPM instance.

---

## 5. Basic health checks

On the instance, you can sanity-check everything:

```bash
# Check systemd services
sudo systemctl status docker
sudo systemctl status npm
sudo systemctl status npm-init

# Check Docker containers
cd /opt/npm
sudo docker compose ps

# Check helper status
sudo npm-helper status
```

If those look good, you’re up and running.

---

## Verify installation

Run these two commands on a fresh instance:

```bash
sudo npm-helper status
sudo npm-helper cert-check
sudo journalctl -u npm-init.service -b --no-pager | tail -n 50
```

---

## Next steps

- See **[Operations](./operations.md)** for CLI usage and logs.
- See **[Security](./security.md)** for SSH, firewall, and admin access posture.
- See **[Backup & Restore](./backup-restore.md)** to set up backups (local + S3).
- See **[Monitoring & Metrics](./monitoring-and-metrics.md)** for CloudWatch logs/metrics.
- See **[Troubleshooting](./troubleshooting.md)** for first-boot recovery and admin UI access checks.
- See **[Upgrades](./upgrades.md)** for upgrade guidance.
- See **[Examples: Multi-App Setup](./examples-multi-app.md)** to host multiple apps behind NPM.
