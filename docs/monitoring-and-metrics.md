# Monitoring & Metrics

This AMI includes a preconfigured Amazon CloudWatch Agent so basic logs and
system-level metrics are available out of the box once the instance is running
with the right permissions.

Product:

**Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions**

---

## IAM Permissions (Optional)

CloudWatch integration is **optional**. This AMI functions normally without any AWS IAM permissions. If no instance role is attached (or permissions are missing), the CloudWatch Agent may log permission errors and will not be able to publish logs/metrics.

### What is shipped to CloudWatch by default

**Logs** (CloudWatch Logs group: `/northstar-cloud-solutions/npm`):

- `/var/log/syslog`
- `/var/log/auth.log`
- `/var/lib/docker/containers/*/*-json.log`

**Metrics** (CloudWatch namespace: `NorthstarCloudSolutions/System`):

- Disk: used percent on `/`
- Memory: used percent
- CPU: idle and iowait
- Network: bytes in/out on the primary interface (typically `eth0`)

Note: this AMI does **not** create alarms, dashboards, or notifications by default.
CloudWatch retention is controlled by your account settings for the log group and metrics.
CloudWatch costs vary by log volume and retention settings; you control retention in CloudWatch.

### Minimal IAM policy (logs + metrics)

Attach an **instance role** with a policy similar to the following. This uses `Resource: "*"` for simplicity; organizations can tighten this further to match their standards.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogsWrite",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchMetricsWrite",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```

### Troubleshooting permissions

- **Agent logs**: `sudo journalctl -u amazon-cloudwatch-agent.service -n 200 --no-pager`
- If you see `AccessDenied` or `UnauthorizedOperation`, attach an instance role with the permissions above and restart the agent: `sudo systemctl restart amazon-cloudwatch-agent.service`

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
/northstar-cloud-solutions/npm
```

Each instance uses separate log streams, for example:

- `{instance_id}-syslog`

- `{instance_id}-auth`

### Metrics

Publish basic system metrics under the CloudWatch namespace:

**NorthstarCloudSolutions/System**

The AMI's default config collects:

- **mem_used_percent** – overall memory usage percentage

- **used_percent (for /)** – disk space used on the root filesystem
