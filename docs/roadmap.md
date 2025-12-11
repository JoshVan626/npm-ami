# Roadmap

This section describes planned future enhancements for the Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions. These are **not required** for day-one
production use but are intended to make the product even more powerful over time.

You can reference this roadmap in the AWS Marketplace listing to show
customers where the product is heading.

---

## Planned: NPM update tooling

Currently, NPM is pinned to a specific Docker image version for stability.
Planned enhancements include:

- A dedicated `npm-update` CLI tool that will:
  - Create a backup of NPM data before updating
  - Pull a new NPM image version (configurable tag)
  - Restart the stack and perform a health check
  - Allow easy rollback if the new version misbehaves

Goal: provide a **safe, repeatable upgrade path** without requiring manual
Docker commands.

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

These will be designed to avoid adding overhead for users who don’t need them.

---

## Planned: Deployment patterns & HA guides

Non-code roadmap items:

- Documentation for:
  - Running NPM behind an AWS Application Load Balancer
  - Using Route 53 health checks and multiple NPM instances for higher
    availability (manual or scripted)
  - Example CloudFormation / Terraform snippets to deploy the AMI in a
    standardized way

Goal: give teams clearer guidance on how to scale from a single NPM instance
to more resilient setups.
