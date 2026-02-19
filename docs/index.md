# Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring

**by Northstar Cloud Solutions**

The **Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring** is a
production-ready reverse proxy for AWS and a hardened, batteries-included EC2 image that gives you:

- A securely configured Nginx Proxy Manager instance (Docker-based, pinned version)
- Opinionated security defaults (SSH hardening, firewall, fail2ban, sysctl)
- First-boot automatic admin credential generation (no default passwords, no secrets in MOTD)
- Built-in backup & restore (local + optional S3)
- Certificate expiry monitoring with daily checks
- CloudWatch logging for system/auth activity
- Simple CLI helpers for status, credential retrieval, backups, and safe upgrades

**Naming & platform layer:** The application is Nginx Proxy Manager (NPM). References to `northstar` in commands, paths, or systemd units refer to Northstar Cloud Solutions’ lifecycle and hardening layer around the upstream NPM container.

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
  - Credentials are written to a root-only file (see `docs/security.md`)
  - The login banner shows **no secrets** and points to `npm-helper show-creds`
- **Security baseline:**
  - Password SSH login disabled
  - Root SSH login disabled
  - UFW firewall with only `22, 80, 443` open by default
  - Port `81` is restricted and must be allowlisted or tunneled
  - Fail2ban for SSH
  - Conservative sysctl hardening
- **Ops tools:**
  - `northstar` (recommended wrapper CLI)
  - `npm-helper` (show/rotate credentials, check status, admin access)
- `npm-helper cert-check`, `npm-helper upgrade`, `npm-helper rollback`, `npm-helper backup verify`
- `northstar observability enable|disable|status` for opt-in baseline
  - `npm-backup` and `npm-restore` (local + optional S3)
  - Daily backup timer via systemd
- **Observability:**
  - Amazon CloudWatch Agent preconfigured to ship system and auth logs
- Per-instance log streams for easier debugging

---

## Architecture (data flow)

```mermaid
flowchart TB
  Internet[(Public Internet)]
  subgraph AWS["AWS VPC"]
    EC2[EC2 Instance\nNginx Proxy Manager (NPM)]
    subgraph Docker["Docker Compose"]
      NPM[NPM Container]
    end
    LocalBackups[(Local Backups\n/var/backups)]
  end
  CloudWatch[(CloudWatch Logs/Metrics\nOptional IAM)]
  S3[(S3 Backups\nOptional IAM)]
  AdminCIDR[Admin IP/CIDR\n(SSH + Admin UI)]
  Tunnel[SSH Tunnel\nlocalhost:8181 → :81]

  Internet -->|80/443| EC2
  AdminCIDR -->|22/81 (restricted)| EC2
  Tunnel -->|81 via SSH| EC2
  EC2 --> Docker
  Docker --> NPM
  EC2 --> LocalBackups
  EC2 -.->|optional| S3
  EC2 -.->|optional| CloudWatch
```

Diagram source: [`docs/assets/architecture.mmd`](./assets/architecture.mmd).

---

## How to use this documentation

- Start with **[Quickstart](./quickstart.md)** – to go from AMI → running NPM in minutes.
- See **[Operations](./operations.md)** for CLI helpers, services, and logging.
- Use **[Backup & Restore](./backup-restore.md)** to protect your config and TLS certs.
- Review **[Security](./security.md)** to understand the hardening choices.
- Check **[Troubleshooting](./troubleshooting.md)** when something doesn't work.
- See **Troubleshooting** for first-boot recovery commands (preflight/init/post-init) and CloudWatch IAM-optional expectations.
- See **[Monitoring & Metrics](./monitoring-and-metrics.md)** for CloudWatch logs and metrics.
- See **[Upgrades](./upgrades.md)** for upgrading the AMI and NPM versions.
- See **[DNS and certificate patterns](./dns-cert-patterns.md)** for turnkey DNS (Route53, CloudFlare) and cert management.
- See **[Reliability Scorecard](./reliability-scorecard.md)** for local-only reliability artifact format and generation.
- See **[Releases](../RELEASES.md)** for AMI/NPM compatibility matrix and release-specific upgrade guidance.
- See **[Examples: Multi-App Setup](./examples-multi-app.md)** for a common use case.
- Look at **[Roadmap](./roadmap.md)** for planned future enhancements.
- Review **[Releases](../RELEASES.md)** for a repository release log scaffold.
