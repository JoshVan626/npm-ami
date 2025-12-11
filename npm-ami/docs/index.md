# Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions

The **Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions** is a hardened,
batteries-included EC2 image that gives you:

- A securely configured Nginx Proxy Manager instance (Docker-based, pinned version)
- Opinionated security defaults (SSH hardening, firewall, fail2ban, sysctl)
- First-boot automatic admin credential generation (no default passwords)
- Built-in backup & restore (local + optional S3)
- CloudWatch logging for system/auth activity
- Simple CLI helpers for status, password rotation, and backups

It’s designed for:

- Solo devs and small teams who want a **simple, secure reverse proxy** on AWS
- Small SaaS / agencies hosting multiple apps behind one EC2 instance
- People who are comfortable with EC2 but don’t want to reinvent hardening,
  backups, and operational glue around NPM

---

## What you get out of the box

- **Nginx Proxy Manager in Docker**, pinned to a known-good version
- **Secure first boot:**
  - A strong random admin password is generated on first boot
  - Password is written to `/root/npm-admin-credentials.txt` (root-only)
  - A login banner shows URL + credentials on SSH login
- **Security baseline:**
  - Password SSH login disabled
  - Root SSH login disabled
  - UFW firewall with only `22, 80, 81, 443` open
  - Fail2ban for SSH
  - Conservative sysctl hardening
- **Ops tools:**
  - `npm-helper` (show/rotate admin credentials, check status)
  - `npm-backup` and `npm-restore` (local + optional S3)
  - Daily backup timer via systemd
- **Observability:**
  - Amazon CloudWatch Agent preconfigured to ship system and auth logs
  - Per-instance log streams for easier debugging

---

## How to use this documentation

- Start with **[Quickstart](./quickstart.md)** – to go from AMI → running NPM in minutes.
- See **[Operations](./operations.md)** for CLI helpers, services, and logging.
- Use **[Backup & Restore](./backup-restore.md)** to protect your config and TLS certs.
- Review **[Security](./security.md)** to understand the hardening choices.
- Check **[Troubleshooting](./troubleshooting.md)** when something doesn't work.
- See **[Monitoring & Metrics](./monitoring-and-metrics.md)** for CloudWatch logs and metrics.
- See **[Upgrades](./upgrades.md)** for upgrading the AMI and NPM versions.
- See **[Examples: Multi-App Setup](./examples-multi-app.md)** for a common use case.
- Look at **[Roadmap](./roadmap.md)** for planned future enhancements.
