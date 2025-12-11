# Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)

**By Northstar Cloud Solutions**

A hardened, ready-to-run AWS AMI that provides a secure Nginx Proxy Manager instance with Docker, automatic credential generation, built-in backups, and CloudWatch integration.

---

## Overview

This repository contains all the files, scripts, and documentation needed to build the **Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)** AMI for AWS Marketplace.

### What This AMI Provides

- **Secure Ubuntu 22.04 LTS** base with hardening applied
- **Docker Engine + Docker Compose** pre-installed
- **Nginx Proxy Manager** in a Docker container (pinned version)
- **Automatic first-boot setup** with secure password generation
- **Built-in backup & restore** tools (local + optional S3)
- **CloudWatch integration** for logs and metrics
- **Security hardening** (SSH, UFW, fail2ban, sysctl)
- **Operational tools** (`npm-helper`, `npm-diagnostics`, `npm-support-bundle`)

---

## Quick Start

### For Builders (Creating the AMI)

1. **Prerequisites:**
   - AWS account with EC2 access
   - Ubuntu 22.04 EC2 instance (builder instance)
   - Git installed

2. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd npm-ami
   ```

3. **Follow the build runbook:**
   - See [`build-runbook.md`](build-runbook.md) for detailed instructions
   - Run scripts `00-05` in order on a fresh Ubuntu 22.04 instance
   - Create AMI snapshot after running cleanup script

4. **Test the AMI:**
   - See [`docs/testing-checklist.md`](docs/testing-checklist.md) for validation steps
   - Launch a new instance from the AMI
   - Verify all functionality works

### For Users (Using the AMI)

- **Quickstart Guide:** [`docs/quickstart.md`](docs/quickstart.md)
- **Full Documentation:** [`docs/index.md`](docs/index.md)

---

## Repository Structure

```
npm-ami/
├── README.md                    # This file
├── build-runbook.md            # Build instructions
├── product-spec.md             # Product specification
├── ami-files/                  # Files that go into the AMI
│   ├── opt-npm/                # NPM Docker Compose config
│   ├── usr-local-bin/          # Helper scripts (npm-helper, etc.)
│   ├── etc-systemd-system/     # Systemd service units
│   ├── etc-fail2ban/           # Fail2ban configuration
│   ├── etc-sysctl.d/           # Sysctl hardening
│   ├── etc/                    # Config files (issue.net, backup config)
│   └── opt-aws/                # CloudWatch Agent config
├── scripts/                    # Build scripts (run in order 00-05)
│   ├── 00-base-packages.sh
│   ├── 01-install-docker.sh
│   ├── 02-setup-npm-stack.sh
│   ├── 03-security-hardening.sh
│   ├── 04-cloudwatch-setup.sh
│   └── 05-cleanup-for-ami.sh
└── docs/                       # User and builder documentation
    ├── index.md                # Documentation index
    ├── quickstart.md           # Getting started guide
    ├── operations.md           # CLI tools and services
    ├── backup-restore.md       # Backup/restore guide
    ├── security.md             # Security features
    ├── monitoring-and-metrics.md # CloudWatch setup
    ├── upgrades.md             # Upgrade procedures
    ├── troubleshooting.md      # Common issues
    ├── testing-checklist.md    # AMI validation checklist
    └── ...
```

---

## Documentation

### For Builders

- **[Build Runbook](build-runbook.md)** - Step-by-step AMI build process
- **[Testing Checklist](docs/testing-checklist.md)** - Validation steps before publishing
- **[Product Specification](product-spec.md)** - Complete product requirements

### For Users

- **[Documentation Index](docs/index.md)** - Start here for user docs
- **[Quickstart](docs/quickstart.md)** - Get running in minutes
- **[Operations](docs/operations.md)** - CLI tools and services
- **[Backup & Restore](docs/backup-restore.md)** - Data protection
- **[Security](docs/security.md)** - Security features explained
- **[Monitoring & Metrics](docs/monitoring-and-metrics.md)** - CloudWatch setup
- **[Upgrades](docs/upgrades.md)** - Upgrade procedures
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

---

## Key Features

### Security

- SSH key-only authentication (password auth disabled)
- Root login disabled
- UFW firewall with minimal open ports (22, 80, 81, 443)
- Fail2ban for SSH protection
- Conservative sysctl network hardening
- Unique SSH host keys per instance

### First Boot Automation

- Automatic NPM container startup
- Secure random admin password generation
- Credentials displayed in SSH login banner (MOTD)
- One-time initialization (never runs twice)

### Operational Tools

- **`npm-helper`** - Show/rotate admin credentials, check status
- **`npm-backup`** - Create backups (local + optional S3)
- **`npm-restore`** - Restore from backup archives
- **`npm-diagnostics`** - System health check
- **`npm-support-bundle`** - Collect diagnostics for support

### Observability

- CloudWatch Logs: `/Northstar/npm` log group
- CloudWatch Metrics: `Northstar/System` namespace
- System logs (syslog, auth.log)
- Memory and disk usage metrics

---

## Build Process

The AMI is built by running numbered scripts in sequence on a fresh Ubuntu 22.04 EC2 instance:

1. **`00-base-packages.sh`** - Install base packages and dependencies
2. **`01-install-docker.sh`** - Install Docker Engine and Compose
3. **`02-setup-npm-stack.sh`** - Copy NPM files and configure systemd
4. **`03-security-hardening.sh`** - Apply SSH, UFW, fail2ban, sysctl configs
5. **`04-cloudwatch-setup.sh`** - Install and configure CloudWatch Agent
6. **`05-cleanup-for-ami.sh`** - Remove instance-specific data before snapshot

After running all scripts, create an AMI snapshot from the instance.

See [`build-runbook.md`](build-runbook.md) for detailed instructions.

---

## Testing

Before publishing the AMI, validate it using the comprehensive checklist:

- **[Testing Checklist](docs/testing-checklist.md)**

This covers:
- Pre-build validation
- Build process verification
- First boot testing
- Functional validation
- Security validation
- AMI snapshot testing

---

## Support

For issues, questions, or support requests related to this AMI:

- **Documentation:** See [`docs/`](docs/) directory
- **Troubleshooting:** [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **Support:** Contact Northstar Cloud Solutions support

---

## License & Copyright

Copyright © Northstar Cloud Solutions. All rights reserved.

This AMI is provided for use on AWS Marketplace. See product listing for terms and conditions.

---

## Product Information

- **Product Name:** Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions
- **Base OS:** Ubuntu Server 22.04 LTS
- **NPM Version:** Pinned to tested Docker image tag (see `ami-files/opt-npm/docker-compose.yml`)
- **CloudWatch Log Group:** `/Northstar/npm`
- **CloudWatch Metrics Namespace:** `Northstar/System`

---

## Contributing

This repository is for building the official AMI. For feature requests or bug reports, please contact Northstar Cloud Solutions support.



