## Deploy templates

This folder contains copy-paste Infrastructure-as-Code templates to launch the **Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04)** AMI.

These templates create:
- An EC2 instance (`t3.small` by default)
- A security group allowing inbound `22`, `80`, `81`, `443` from `0.0.0.0/0`
- An instance role + instance profile with permissions for optional CloudWatch Logs/Metrics and optional S3 backups

### Terraform

From `deploy/terraform/`:

```bash
terraform init
terraform apply \
  -var aws_region=us-east-1 \
  -var vpc_id=vpc-xxxxxxxx \
  -var subnet_id=subnet-xxxxxxxx \
  -var key_name=YOUR_KEYPAIR_NAME
```

Notes:
- The AMI is discovered via an `aws_ami` data source using the name pattern `npm-hardened-edition-ubuntu22-*`.
- If your Marketplace AMI is owned by a different account than the default (`aws-marketplace`), set `-var 'ami_owners=["<owner-id>"]'`.

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
    ParameterKey=SubnetId,ParameterValue=subnet-xxxxxxxx
```

After the stack completes, use the `NginxProxyManagerURL` output to access the UI.
