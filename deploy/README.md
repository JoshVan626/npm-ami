## Deploy templates

This folder contains copy-paste Infrastructure-as-Code templates to launch the **Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring** AMI.

These templates create:
- An EC2 instance (`t3.small` by default)
- A security group with public 80/443 and restricted admin ports (22/81)
- An instance role + instance profile with permissions for optional CloudWatch Logs/Metrics and optional S3 backups

### Terraform

From `deploy/terraform/`:

```bash
terraform init
terraform apply \
  -var aws_region=us-east-1 \
  -var vpc_id=vpc-xxxxxxxx \
  -var subnet_id=subnet-xxxxxxxx \
  -var key_name=YOUR_KEYPAIR_NAME \
  -var 'admin_cidrs=["203.0.113.10/32"]'
```

Notes:
- The AMI is discovered via an `aws_ami` data source using the name pattern `npm-hardened-edition-ubuntu22-*`.
- If your Marketplace AMI is owned by a different account than the default (`aws-marketplace`), set `-var 'ami_owners=["<owner-id>"]'`.
- **Security group guidance:** restrict `22/tcp` and `81/tcp` to your admin IPs, keep `80/443` public, and avoid public exposure of `81/tcp` (use allowlist or SSH tunnel).
- **Allowing 0.0.0.0/0 for admin ports is blocked by default.** If you must override (not recommended), set `-var allow_admin_from_anywhere=true`.

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
  --parameters \
    ParameterKey=AmiId,ParameterValue=ami-xxxxxxxxxxxxxxxxx \
    ParameterKey=KeyName,ParameterValue=YOUR_KEYPAIR_NAME \
    ParameterKey=VpcId,ParameterValue=vpc-xxxxxxxx \
    ParameterKey=SubnetId,ParameterValue=subnet-xxxxxxxx \
    ParameterKey=AdminCidr,ParameterValue=203.0.113.10/32
```

After the stack completes, use the `NginxProxyManagerAdminURL` output to access the UI.
