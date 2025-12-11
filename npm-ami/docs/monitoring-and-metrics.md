# Monitoring & Metrics

This AMI includes a preconfigured Amazon CloudWatch Agent so basic logs and
system-level metrics are available out of the box once the instance is running
with the right permissions.

Product:

**Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions**

---

## What the AMI is configured to send

The CloudWatch Agent is installed and configured via:

- Config file: `/opt/aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json`

- Service: `amazon-cloudwatch-agent.service`

When the instance is running with permissions to talk to CloudWatch, it will:

### Logs

Send these log files:

- `/var/log/syslog`

- `/var/log/auth.log`

to the CloudWatch Logs **log group**:

```text
/Northstar/npm
```

Each instance uses separate log streams, for example:

- `{instance_id}-syslog`

- `{instance_id}-auth`

### Metrics

Publish basic system metrics under the CloudWatch namespace:

**Northstar/System**

The AMI's default config collects:

- **mem_used_percent** – overall memory usage percentage

- **used_percent (for /)** – disk space used on the root filesystem
