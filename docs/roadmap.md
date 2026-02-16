# Roadmap

This section describes planned future enhancements for the Nginx Proxy Manager (NPM) for AWS by Northstar Cloud Solutions. These are **not required** for day-one
production use but are intended to make the product even more powerful over time.

You can reference this roadmap in the AWS Marketplace listing to show
customers where the product is heading.

---

## Shipped: NPM upgrade tooling

The AMI includes safe, repeatable upgrade and rollback tooling:

- **`npm-helper upgrade`** – Backup-first upgrade workflow with preflight checks; supports `--dry-run` and `--auto-rollback` on health check failure
- **`npm-helper rollback`** – One-command rollback to last-known-good state using upgrade metadata
- **`npm-update-container`** – Updates the pinned NPM Docker image with safety backup and rollback support

See [Upgrades](upgrades.md) for full guidance.

---

## Planned: HA / multi-node reference architecture

- Documentation and examples for:
  - Running NPM behind an AWS Application Load Balancer
  - Route 53 health checks and multiple NPM instances for higher availability
  - Manual or scripted failover patterns

Goal: give teams clearer guidance on scaling from a single NPM instance to more resilient setups.

---

## Planned: Optional SSO/IdP integration

- Integration with identity providers (OAuth2, SAML) for NPM admin UI access
- Single sign-on for teams with existing IdP infrastructure

---

## Planned: Route 53 automation

- Optional automation for DNS record management (e.g., A/AAAA records for proxy hosts)
- Integration with Let's Encrypt HTTP-01 and DNS-01 challenges

---

## Planned: Optional customization via config

Introduce a small configuration file (for example `/etc/npm-ami.conf`) that
lets advanced users customize certain defaults without editing code, such as:

- Default admin email (instead of the built-in `admin@example.com`)
- Branding information for MOTD banner and SSH banner
- Optional tuning of backup behavior beyond what `/etc/npm-backup.conf` offers

Goal: make the AMI more flexible for MSPs and teams with specific policies,
while keeping the default experience simple.

---

## Planned: Additional logging options

Potential enhancements:

- Optional collection of NPM application logs into CloudWatch Logs
- Example dashboards/queries to monitor NPM activity

These will be designed to avoid adding overhead for users who don't need them.
