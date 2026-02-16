# MSP Guide

Guide for managed service providers (MSPs) managing multiple NPM for AWS instances across customers or VPCs.

---

## Use case

- Stand up a **repeatable proxy appliance** per client or per VPC
- Standardize deployment and hardening across customer environments
- Reduce per-customer setup time and configuration drift

---

## Deployment at scale

Use Terraform or CloudFormation to deploy the AMI in a consistent way. The [deploy/](../deploy/) folder contains templates you can adapt.

### Multi-account or multi-VPC

- Use variables/parameters for: `admin_cidrs`, `backup_bucket_name`, `backup_prefix`, `instance_type`
- Consider separate Terraform workspaces or CloudFormation stacks per customer
- Scope IAM roles to customer-specific buckets and log groups where possible

### Example Terraform variables per customer

```hcl
variable "admin_cidrs" {
  description = "CIDRs allowed for SSH and admin UI"
  type        = list(string)
}

variable "backup_bucket_name" {
  description = "S3 bucket for backups (optional)"
  type        = string
  default     = ""
}

variable "backup_prefix" {
  description = "S3 prefix for backups"
  type        = string
  default     = "npm"
}
```

---

## Standard checklist per customer

Before or right after launch:

| Item | Action |
|------|--------|
| Security group | Restrict 22/81 to admin CIDRs; keep 80/443 open as needed |
| Backup bucket | Configure `s3_bucket` in `/etc/npm-backup.conf` if using S3 |
| Admin CIDR | Set customer or MSP admin IP(s) in IaC or via `npm-helper admin-access enable --cidr <cidr>` |
| Instance role | Attach IAM role for CloudWatch and S3 if using those features |

---

## Remote troubleshooting

Use the built-in support tooling for diagnostics without direct console access:

1. **Support bundle** – Collects logs, configs, and status:
   ```bash
   sudo npm-support-bundle
   ```

2. **Diagnostics (JSON)** – Machine-readable status:
   ```bash
   sudo npm-helper diagnostics --json
   ```

Have the customer run these and share the outputs (after redacting secrets). See [Operations – Support Bundles](operations.md#support-bundles).

---

## Backup and restore discipline

- Enable daily backup timer (enabled by default)
- Configure S3 upload per customer when possible for off-instance copies
- Document restore procedure for each customer
- Before upgrades, run `sudo npm-helper backup verify` to confirm backups

See [Backup & Restore](backup-restore.md).

---

## Related resources

- [Deploy templates](../deploy/README.md) – Terraform and CloudFormation
- [Quickstart](quickstart.md) – Launch and first login
- [Upgrades](upgrades.md) – Upgrade and rollback workflows
- [Troubleshooting](troubleshooting.md) – Common issues and recovery
