# Quickstart

This guide walks you from **nothing** to a working Nginx Proxy Manager admin
panel on AWS using the Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions.

> Assumes: you’re familiar with launching EC2 instances and security groups.

---

## 1. Launch the EC2 instance

1. In the AWS Console, go to **EC2 → AMIs**.
2. Select the **Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions**.
3. Click **Launch instance**.
4. Choose an instance type:
   - For testing: `t3.micro` / `t3.small`
   - For light production: `t3.medium` or higher (depending on traffic)
5. Select / create a key pair.
6. Configure **network and security group** to allow:
   - `22/tcp` – SSH
   - `80/tcp` – HTTP
   - `81/tcp` – NPM admin UI
   - `443/tcp` – HTTPS
7. Launch the instance.

---

## 2. First SSH login & credentials

Once the instance is running:

1. SSH in as `ubuntu`:

   ```bash
   ssh -i /path/to/key.pem ubuntu@<instance-public-ip>
   ```

2. On login, you will see a **MOTD banner** that looks like:

   ```text
   Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions

   Admin URL: http://<instance-ip>:81
   Username: admin@example.com
   Password: <generated-strong-password> (shown on first login only)
   ```

3. Credentials are shown on the **first SSH login** via the MOTD banner. For security, they are not re-printed on future logins.

   If you need to retrieve or rotate credentials later, see **Security** (`docs/security.md`) and use `sudo npm-helper rotate-admin`.

---

## 3. Log into Nginx Proxy Manager

1. Open your browser to:

   ```text
   http://<instance-public-ip>:81
   ```

2. Log in with the **username and password** from the MOTD or credentials file.
3. You’re now in the NPM admin interface.

---

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

## Next steps

- See **[Operations](./operations.md)** for CLI usage and logs.
- See **[Backup & Restore](./backup-restore.md)** to set up backups (local + S3).
- See **[Examples: Multi-App Setup](./examples-multi-app.md)** to host multiple apps behind NPM.
