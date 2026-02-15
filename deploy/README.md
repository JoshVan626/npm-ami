## Deploy templates

This folder contains copy-paste Infrastructure-as-Code templates to launch **Nginx Proxy Manager (NPM) for AWS — by Northstar Cloud Solutions**.

These templates create:
- An EC2 instance (`t3.small` by default)
- A security group with **public 80/443** and **restricted admin ports (22/81)**. Review and tighten for your environment; **do not expose 81 publicly**.
- An instance role + instance profile with permissions for optional CloudWatch Logs/Metrics and optional S3 backups

### Terraform

From `deploy/terraform/`:

```bash
terraform init
terraform apply \
  -var-file=examples/minimal.tfvars
```

Secure profile example:

```bash
terraform apply -var-file=examples/secure.tfvars
```

Notes:
- The AMI is discovered via an `aws_ami` data source using the name pattern `npm-hardened-edition-ubuntu22-*`.
- If your Marketplace AMI is owned by a different account than the default (`aws-marketplace`), set `-var 'ami_owners=["<owner-id>"]'`.
- **Security group guidance:** restrict `22/tcp` and `81/tcp` to your admin IPs, keep `80/443` public, and avoid public exposure of `81/tcp` (use allowlist or SSH tunnel). AdminCidr/admin_cidrs defaults to `127.0.0.1/32` to prevent accidental public exposure; set it to your public IP/32 before launch.
- **Admin port 81 has two gates:** (1) the EC2 security group must allow your source CIDR on `81/tcp`, and (2) the instance firewall/UFW must allow it, typically managed via `npm-helper admin-access` or by using an SSH tunnel.
- **Allowing 0.0.0.0/0 for admin ports is blocked by default.** If you must override (not recommended), set `-var allow_admin_from_anywhere=true`.
- **Optional S3 scoping:** set `-var backup_bucket_name` and (optionally) `-var backup_prefix` to scope the instance role to your backup bucket/prefix instead of `*`.
- **Optional IAM profile attach:** set `create_instance_profile=true` to attach CloudWatch/S3 backup permissions.
- **Optional EIP:** set `associate_eip=true` to allocate and attach an Elastic IP.
- **Optional root EBS tuning:** set `root_volume_size` and `root_volume_type`.

SSH tunnel for admin UI (recommended):

```bash
ssh -i /path/to/key.pem -L 8181:localhost:81 ubuntu@<instance-public-ip>
```

Then open `http://localhost:8181` in your browser.

### CloudFormation

This template requires an `AmiId` parameter (AMI IDs are region-specific).

```bash
aws cloudformation create-stack \
  --stack-name npm-hardened-edition \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-body file://deploy/cloudformation/template.yaml \
  --parameters file://deploy/cloudformation/examples/minimal-params.json
```

Secure profile example:

```bash
aws cloudformation create-stack \
  --stack-name npm-hardened-edition-secure \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-body file://deploy/cloudformation/template.yaml \
  --parameters file://deploy/cloudformation/examples/secure-params.json
```

Notes:
- AdminCidr defaults to `127.0.0.1/32` to prevent accidental public exposure; set it to your public IP/32 before launch.
- To scope S3 backup permissions, provide `BackupBucketName` and (optionally) `BackupPrefix`. If omitted, the template preserves the existing broad S3 permissions.
- `AttachInstanceProfile` and `AssociateEip` default to `false` for minimal-risk launches.
- CloudWatch dashboards/alarms are opt-in via runtime command: `sudo northstar observability enable`.

After the stack completes, use the `NginxProxyManagerAdminURL` output to access the UI.
