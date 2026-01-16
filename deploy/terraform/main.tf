terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access."
  type        = string
}

variable "public_cidrs" {
  description = "CIDRs allowed to reach public ports (80/443)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach admin ports (22/81). Defaults to 127.0.0.1/32 for safety; set to your public IP/32. Do not use 0.0.0.0/0 or ::/0 for port 81."
  type        = list(string)
  default     = ["127.0.0.1/32"]
}

variable "allow_admin_from_anywhere" {
  description = "If true, allow admin_cidrs to include 0.0.0.0/0 or ::/0 (strongly discouraged)."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Instance type to use (recommended: t3.small)."
  type        = string
  default     = "t3.small"
}

variable "ami_name_pattern" {
  description = "AMI name pattern used to discover the latest AMI."
  type        = string
  default     = "npm-hardened-edition-ubuntu22-*"
}

variable "ami_owners" {
  description = "AMI owners to search. Defaults to aws-marketplace; override if your AMI is owned by a specific account."
  type        = list(string)
  default     = ["aws-marketplace"]
}

variable "backup_bucket_name" {
  description = "Optional: S3 bucket name for backups (used only to scope IAM policy)."
  type        = string
  default     = ""
}

variable "backup_prefix" {
  description = "Optional: S3 key prefix for backups (example: npm-backups/)."
  type        = string
  default     = "npm-backups/"
}

locals {
  has_backup_bucket = length(var.backup_bucket_name) > 0
  has_backup_prefix = length(var.backup_prefix) > 0
  backup_object_arn = local.has_backup_prefix ? "arn:aws:s3:::${var.backup_bucket_name}/${var.backup_prefix}*" : "arn:aws:s3:::${var.backup_bucket_name}/*"
  backup_list_prefix = local.has_backup_prefix ? "${var.backup_prefix}*" : "*"
}

data "aws_ami" "npm" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_iam_role" "instance" {
  name = "npm-hardened-edition-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "instance" {
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchMetricsWrite"
    effect = "Allow"

    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = local.has_backup_bucket ? [1] : []
    content {
      sid    = "S3BackupsWrite"
      effect = "Allow"

      actions = [
        "s3:PutObject",
        "s3:AbortMultipartUpload"
      ]

      resources = [local.backup_object_arn]
    }
  }

  dynamic "statement" {
    for_each = local.has_backup_bucket ? [1] : []
    content {
      sid    = "S3BackupsList"
      effect = "Allow"

      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]

      resources = ["arn:aws:s3:::${var.backup_bucket_name}"]

      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = [local.backup_list_prefix]
      }
    }
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "npm-hardened-edition-instance-policy"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "npm-hardened-edition-instance-profile"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "npm" {
  name        = "npm-hardened-edition-sg"
  description = "Nginx Proxy Manager (NPM) for AWS — allow 80/443 public; restrict 22/81 to admin CIDRs"
  vpc_id      = var.vpc_id

  lifecycle {
    precondition {
      condition     = var.allow_admin_from_anywhere || (!contains(var.admin_cidrs, "0.0.0.0/0") && !contains(var.admin_cidrs, "::/0"))
      error_message = "admin_cidrs must not include 0.0.0.0/0 or ::/0 unless allow_admin_from_anywhere is true."
    }
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.public_cidrs
  }

  ingress {
    description = "NPM UI"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "npm-hardened-edition-sg"
  }
}

resource "aws_instance" "npm" {
  ami                    = data.aws_ami.npm.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.npm.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  tags = {
    Name = "npm-hardened-edition"
  }
}

output "instance_public_ip" {
  value       = aws_instance.npm.public_ip
  description = "Public IP of the Nginx Proxy Manager (NPM) for AWS instance."
}

output "nginx_proxy_manager_url" {
  value       = "http://${aws_instance.npm.public_ip}:81"
  description = "Nginx Proxy Manager (NPM) for AWS admin UI URL (use SSH tunnel or allowlist a trusted IP)."
}
