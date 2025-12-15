# Northstar Cloud Solutions LLC — AMI Releases

This document is the authoritative record of published AMI versions and their per-region AMI IDs.

IMPORTANT:
- Populate this file with **real AMI IDs after the first bake**.
- AWS Marketplace submission must **not** proceed until the release entry has **TBD replaced** with real AMI IDs for the intended regions.

---

## Versioning

- Releases use semantic versioning: **MAJOR.MINOR.PATCH** (for example: `v1.2.3`).
- Each release is tied to a specific **git commit** for traceability and reproducibility.
- Each release pins a specific **Nginx Proxy Manager Docker image tag** (defined in `ami-files/opt-npm/docker-compose.yml`).
- Containers are **not automatically upgraded**.
- Recommended upgrade path: **launch a newer AMI version** and restore configuration using `npm-backup` / `npm-restore`.

---

## Release Records

Each release record tracks:

- Version
- Release date
- Git commit
- Pinned components (Ubuntu version and NPM Docker image tag)
- Notable changes (high-level)
- AMI IDs by AWS region (recorded after publication)

---

## PRE-BUILD TEMPLATE — RC-0

Use this entry during pre-release testing before any Marketplace submission.

- **Version**: `0.1.0-rc.0`
- **Release date**: `<YYYY-MM-DD>`
- **Git commit**: `<commit-sha>`
- **Ubuntu**: `22.04`
- **Pinned NPM image**: `jc21/nginx-proxy-manager:2.13.5`

### AMI IDs by region (TBD until baked)

| Region | AMI ID |
|--------|--------|
| us-east-1 | TBD |
| us-east-2 | TBD |
| us-west-1 | TBD |
| us-west-2 | TBD |
| eu-west-1 | TBD |

---

## v1.0.0 (Template)

- **Release date**: `<YYYY-MM-DD>`
- **Git commit**: `<commit-sha>`
- **Ubuntu**: `22.04`
- **Pinned NPM image**: `jc21/nginx-proxy-manager:2.13.5`

### Notable changes

- First-boot workflow: `npm-preflight.service` → `npm-init.service` → `npm-postinit.service`
- Systemd-managed NPM stack (`npm.service`) using Docker + Docker Compose
- Backup/restore tooling (`npm-backup`, `npm-restore`) with local retention and optional S3 uploads
- Optional CloudWatch Agent configuration for logs and system metrics
- Baseline hardening (SSH, UFW, fail2ban, sysctl)

### AMI IDs by region

| Region | AMI ID |
|--------|--------|
| us-east-1 | TBD |
| us-east-2 | TBD |
| us-west-1 | TBD |
| us-west-2 | TBD |
| eu-west-1 | TBD |

---

## v1.0.1 (Template)

- **Release date**: `<YYYY-MM-DD>`
- **Git commit**: `<commit-sha>`
- **Ubuntu**: `22.04`
- **Pinned NPM image**: `<unchanged or updated tag>`

### Notable changes

- `<bullet>`

### AMI IDs by region

| Region | AMI ID |
|--------|--------|
| us-east-1 | `<ami-id>` |
| us-east-2 | `<ami-id>` |
| us-west-1 | `<ami-id>` |
| us-west-2 | `<ami-id>` |
| eu-west-1 | `<ami-id>` |
