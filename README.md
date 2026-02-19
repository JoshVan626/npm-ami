# Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring

**by Northstar Cloud Solutions LLC**

A hardened, ready-to-run AWS AMI that provides a **production-ready reverse proxy for AWS** with Nginx Proxy Manager (NPM), Docker, secure credential generation, built-in backups, and optional CloudWatch integration.

---

## Overview

This repository contains documentation and supporting artifacts for the **Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring** Amazon Machine Image (AMI), published by **Northstar Cloud Solutions LLC** on AWS Marketplace.

The AMI is designed to provide a secure, reproducible, and low-maintenance **single-node** Nginx Proxy Manager environment with strong defaults and minimal operational overhead.

**Naming & platform layer:** The application is Nginx Proxy Manager (NPM). References to `northstar` in commands, paths, and systemd units refer to Northstar Cloud Solutions’ lifecycle and hardening layer that wraps the upstream NPM container.

This repository is **not** intended to be a general-purpose installation guide. Customers are expected to launch the AMI directly from AWS Marketplace.

---

## What This AMI Provides

- **Secure Ubuntu 22.04 LTS** base with hardening applied
- **Docker Engine + Docker Compose** pre-installed
- **Nginx Proxy Manager** running in a pinned Docker image
- **Automatic first-boot initialization** with secure credential generation (no secrets printed in MOTD)
- **Built-in backup & restore tooling** (local + optional S3)
- **Amazon CloudWatch integration** for logs and metrics
- **Automated rollback tooling** for upgrade failures (manual and opt-in auto-rollback)
- **One-command observability baseline** (opt-in dashboard + alarms)
- **Security hardening** (SSH, UFW, fail2ban, sysctl) with a restricted admin plane by default
- **Operational helper tools**:
  - `northstar` (recommended wrapper)
  - `npm-helper`
  - `npm-cert-check`
  - `npm-backup`
  - `npm-restore`
  - `npm-diagnostics`
- `npm-support-bundle`
- `npm-update-container` (`--rollback` supported)

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

Diagram source: [`docs/assets/architecture.mmd`](docs/assets/architecture.mmd).

---

## Enterprise Infrastructure as Code (IaC)

Production deployments deserve repeatable, auditable infrastructure. This AMI ships with **ready-to-use Terraform and CloudFormation templates** in the [`deploy/`](deploy/) directory so you can launch hardened NPM instances through your existing IaC pipelines.

| Template | Path | Quick Start |
|---|---|---|
| **Terraform** | [`deploy/terraform/main.tf`](deploy/terraform/main.tf) | `terraform apply -var-file=examples/minimal.tfvars` |
| **CloudFormation** | [`deploy/cloudformation/template.yaml`](deploy/cloudformation/template.yaml) | `aws cloudformation create-stack --template-body file://deploy/cloudformation/template.yaml` |

Both templates create:

- An EC2 instance with the hardened AMI
- A security group with public 80/443 and **restricted admin ports** (22/81)
- An IAM instance role and instance profile for optional CloudWatch and S3 backup permissions
- Optional Elastic IP association

Example configurations for both minimal and security-hardened deployments are included:

- Terraform: [`deploy/terraform/examples/`](deploy/terraform/examples/)
- CloudFormation: [`deploy/cloudformation/examples/`](deploy/cloudformation/examples/)

Full deployment instructions: [`deploy/README.md`](deploy/README.md)

---

## Getting Started (AMI Users)

After launching the AMI from AWS Marketplace:

- **Quickstart Guide:** [`docs/quickstart.md`](docs/quickstart.md)
- **Documentation Index:** [`docs/index.md`](docs/index.md)

The Quickstart covers:
- First login and credential retrieval
- Accessing the Nginx Proxy Manager UI
- Basic security and networking requirements

Use `northstar` (recommended) or `npm-helper` directly for lifecycle and security actions.

---

## Expected first boot timeline (2–5 minutes)

On first boot, the instance initializes NPM, generates admin credentials, and starts the stack. This usually completes in **2–5 minutes** depending on instance size and image pull speed.

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

## Verify installation

Run these two commands on a fresh instance:

```bash
sudo npm-helper status
sudo npm-helper cert-check
sudo journalctl -u npm-init.service -b --no-pager | tail -n 50
```

---

## Shared Responsibility Model

This AMI provides a hardened **single-node** Nginx Proxy Manager environment.

### Customer Responsibilities

Customers are responsible for:
- AWS VPC networking and security group configuration
- DNS configuration and domain ownership
- TLS certificate issuance and renewal within Nginx Proxy Manager
- IAM roles and permissions for optional S3 backups and CloudWatch access
- Ongoing proxy, host, and certificate configuration inside the NPM UI

### Vendor Responsibilities

Northstar Cloud Solutions LLC is responsible for:
- AMI build integrity and reproducibility
- First-boot automation and credential generation
- Secure default configuration and OS hardening
- Documented backup and restore tooling
- Pinned and tested application versions at release time

---

## Versioning and Upgrades

### Operating System Updates
- Ubuntu security updates are applied automatically via `unattended-upgrades`.
- Major OS upgrades are not performed automatically.

### Application Versioning
- Nginx Proxy Manager is deployed using a pinned Docker image version.
- Application containers are **not** automatically upgraded.

### Upgrades
- The recommended upgrade path is to **launch a newer AMI version** and restore configuration using the provided `npm-backup` / `npm-restore` tools.
- In-place upgrades may be documented, but they are optional and **not** performed automatically.

### Release Policy
- Each AMI release is built from a specific repository state and tested prior to publication.
- Release notes document version changes and known limitations.
 
**Release notes and AMI IDs:** Release notes and AMI IDs are managed outside this repository (AWS Marketplace metadata and internal release notes).

See [`RELEASES.md`](RELEASES.md) for a repository release log scaffold and update guidance.
Use the compatibility matrix in `RELEASES.md` to map AMI version to pinned NPM image and supported upgrade/rollback commands.

---

## Security Maintenance Policy

- The AMI base OS and Docker/NPM stack are rebuilt on a regular cadence (for example, monthly or as practical) to incorporate upstream security updates and tested changes.
- Critical security issues in the base OS or pinned NPM container image may trigger out-of-band AMI refreshes when practical, but are not guaranteed on a specific timetable.
- Older AMI versions are not guaranteed to receive fixes; customers should prefer the latest Marketplace version and periodically refresh instances from newer images.
- Between AMI releases, OS-level security updates rely on Ubuntu's `unattended-upgrades` and any additional patching policies you apply to your instances.
- All security maintenance and support are provided on a best-effort basis; no formal SLA or uptime guarantee is offered.

---

## Observability

- **CloudWatch Logs**
  - Log group: `/northstar-cloud-solutions/npm`
  - System logs (`syslog`, `auth.log`) and Docker container logs
  - Nginx proxy access and error logs (per-proxy-host visibility)
- **CloudWatch Metrics**
  - Namespace: `NorthstarCloudSolutions/System`
  - Memory and disk usage
- **Opt-in observability baseline command**
  - `sudo northstar observability enable`
  - `sudo northstar observability disable`
  - `sudo northstar observability status`

Cost & permissions notes:
- CloudWatch logs/metrics are optional and require an instance role/policy. CloudWatch costs vary by log volume and retention; you control retention in CloudWatch.
- Optional S3 backups incur S3 costs and require an instance role/policy (see `docs/backup-restore.md`).

## Reliability Scorecard

Reliability metrics are generated locally from test/validation harnesses and written to the repository `metrics/` directory. No runtime telemetry is sent externally.

- Scorecard docs: [`docs/reliability-scorecard.md`](docs/reliability-scorecard.md)
- Example artifacts:
  - [`metrics/reliability-scorecard.example.json`](metrics/reliability-scorecard.example.json)
  - [`metrics/reliability-scorecard.example.md`](metrics/reliability-scorecard.example.md)

---

## Logging disclosure (CloudWatch optional)

When an instance role is attached, the CloudWatch agent can ship:

- `/var/log/syslog`
- `/var/log/auth.log`
- Docker container logs (`/var/lib/docker/containers/*/*-json.log`)
- Nginx proxy access logs (`/opt/npm/data/logs/*_access.log`)
- Nginx proxy error logs (`/opt/npm/data/logs/*_error.log`)
- Basic system metrics (CPU, memory, disk, network)

To disable CloudWatch shipping:

```bash
sudo systemctl disable --now amazon-cloudwatch-agent.service
```

---

## Support

Support is provided on a **best-effort basis**.

**Support contact:**  
📧 **support@northstarcloud.io**

Support includes:
- AMI initialization issues
- Credential recovery using provided tools
- Documented backup and restore workflows
- Clarification of documented behavior

Support does **not** include:
- Custom Nginx or proxy configuration
- DNS, TLS, or domain troubleshooting
- Third-party plugins or integrations

When contacting support, please include:
- AWS region
- AMI version (if applicable)
- Output of `npm-helper status`
- Relevant CloudWatch log excerpts

For common recovery commands and first-boot troubleshooting, see [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## Opening a Support Request

To help us resolve issues quickly and safely, please include the following when opening a support request:

- Run `sudo npm-support-bundle` and attach the resulting archive or clearly specify the path it was written to (for example, under `/var/backups`).
- Run `sudo npm-helper diagnostics --json` and include the JSON output as an attachment or paste (after reviewing for any sensitive information).
- Include relevant, non-sensitive excerpts from `/opt/northstar/build-manifest.txt` such as OS version, kernel version, Docker version, and NPM container image tag.
- Provide a concise problem description: what you expected, what actually happened, when it started, and any recent changes (upgrades, security group changes, backup/restore operations, etc.).
- Do **not** include secrets (passwords, private keys, certificate private key files, or full credentials) in tickets or email.

---

## Marketplace listing draft (internal)

Suggested title:
- **Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring**

Feature bullets (draft):
- Hardened Ubuntu 22.04 baseline with conservative defaults
- Systemd-managed Nginx Proxy Manager stack (Docker + docker compose plugin)
- One-time first-boot initialization (credentials generated per instance)
- Optional backups (local + optional S3)
- Optional CloudWatch Agent configuration (logs + system metrics)
- Included helper tools for status and diagnostics

Shared responsibility (draft):
- Customer controls VPC/security groups, DNS, and application configuration inside NPM
- Optional IAM permissions (CloudWatch/S3) are customer-owned and optional
- Vendor provides the AMI lifecycle automation, hardening, and documented tooling

Keywords (draft):
- nginx proxy manager, reverse proxy, tls, letsencrypt, ubuntu 22.04, docker, systemd, aws marketplace, hardened, fail2ban, ufw, cloudwatch, backup

## Licensing

This repository contains proprietary automation, scripts, and documentation
owned by **Northstar Cloud Solutions LLC**.

The resulting AMI includes third-party software (including Ubuntu Linux,
Docker, Nginx, and Nginx Proxy Manager), each licensed under their respective
licenses.

Nginx Proxy Manager is an upstream project. Any CVEs or vulnerabilities in the Nginx Proxy Manager container image are inherited from upstream. Northstar Cloud Solutions LLC provides the hardened operating system baseline, lifecycle automation, and operational tooling around the pinned application version.

See the [`LICENSE`](LICENSE) file for full terms.

---

## Product Information

- **Product Name:** Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring
- **Vendor:** Northstar Cloud Solutions LLC
- **Base OS:** Ubuntu Server 22.04 LTS
- **NPM Version:** Pinned Docker image (see documentation)
- **CloudWatch Log Group:** `/northstar-cloud-solutions/npm`
- **CloudWatch Metrics Namespace:** `NorthstarCloudSolutions/System`
