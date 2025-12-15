# Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)

**By Northstar Cloud Solutions LLC**

A hardened, ready-to-run AWS AMI that provides a secure Nginx Proxy Manager instance with Docker, automatic credential generation, built-in backups, and CloudWatch integration.

---

## Overview

This repository contains documentation and supporting artifacts for the **Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)** Amazon Machine Image (AMI), published by **Northstar Cloud Solutions LLC** on AWS Marketplace.

The AMI is designed to provide a secure, reproducible, and low-maintenance **single-node** Nginx Proxy Manager environment with strong defaults and minimal operational overhead.

This repository is **not** intended to be a general-purpose installation guide. Customers are expected to launch the AMI directly from AWS Marketplace.

---

## What This AMI Provides

- **Secure Ubuntu 22.04 LTS** base with hardening applied
- **Docker Engine + Docker Compose** pre-installed
- **Nginx Proxy Manager** running in a pinned Docker image
- **Automatic first-boot initialization** with secure credential generation
- **Built-in backup & restore tooling** (local + optional S3)
- **Amazon CloudWatch integration** for logs and metrics
- **Security hardening** (SSH, UFW, fail2ban, sysctl)
- **Operational helper tools**:
  - `npm-helper`
  - `npm-backup`
  - `npm-restore`
  - `npm-diagnostics`
  - `npm-support-bundle`

---

## Getting Started (AMI Users)

After launching the AMI from AWS Marketplace:

- **Quickstart Guide:** [`docs/quickstart.md`](docs/quickstart.md)
- **Documentation Index:** [`docs/index.md`](docs/index.md)

The Quickstart covers:
- First login and credential retrieval
- Accessing the Nginx Proxy Manager UI
- Basic security and networking requirements

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

**Release notes and AMI IDs:** See [`RELEASES.md`](RELEASES.md) for the authoritative per-version release record (including per-region AMI IDs). The AWS Marketplace listing corresponds to a specific version recorded there.

---

## Observability

- **CloudWatch Logs**
  - Log group: `/northstar-cloud-solutions/npm`
  - System logs (`syslog`, `auth.log`)
- **CloudWatch Metrics**
  - Namespace: `NorthstarCloudSolutions/System`
  - Memory and disk usage

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

---

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

- **Product Name:** Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)
- **Vendor:** Northstar Cloud Solutions LLC
- **Base OS:** Ubuntu Server 22.04 LTS
- **NPM Version:** Pinned Docker image (see documentation)
- **CloudWatch Log Group:** `/northstar-cloud-solutions/npm`
- **CloudWatch Metrics Namespace:** `NorthstarCloudSolutions/System`
