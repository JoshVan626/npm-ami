# Monitoring & Metrics

This AMI includes a preconfigured Amazon CloudWatch Agent so basic logs and
system-level metrics are available out of the box once the instance is running
with the right permissions.

Product:

**Nginx Proxy Manager (NPM) for AWS — Production-Ready, Secure Admin Plane, Backups & Monitoring by Northstar Cloud Solutions**

---

## HTTP health endpoint (port 9180)

The AMI includes `npm-health-endpoint.service`, which serves `GET /health` on 127.0.0.1:9180 by default. The endpoint returns JSON `{"status":"pass|warn|fail","checks":[...],"timestamp":"..."}` suitable for ALB/NLB target group health checks, Datadog, or similar monitoring tools.

To expose the endpoint externally for load balancer health checks, configure `/etc/default/npm-health-endpoint` with `NPM_HEALTH_BIND=0.0.0.0` and add port 9180 to the instance security group. See [Operations](operations.md#http-health-endpoint-albnlb-datadog-etc) for details.

---

## IAM Permissions (Optional)

CloudWatch integration is **optional**. This AMI functions normally without any AWS IAM permissions. If no instance role is attached (or permissions are missing), the CloudWatch Agent may log permission errors and will not be able to publish logs/metrics.

## One-command baseline (opt-in)

Enable baseline dashboard + alarms + metric filters:

```bash
sudo northstar observability enable --dry-run
sudo northstar observability enable
```

Disable baseline and remove created resources:

```bash
sudo northstar observability disable
```

Check baseline state:

```bash
sudo northstar observability status
```

Baseline artifacts shipped with the AMI:

- `/opt/aws/amazon-cloudwatch-agent/dashboard.baseline.json`
- `/opt/aws/amazon-cloudwatch-agent/alarms.baseline.json`

### What is shipped to CloudWatch by default

**Logs** (CloudWatch Logs group: `/northstar-cloud-solutions/npm`):

- `/var/log/syslog`
- `/var/log/auth.log`
- `/var/lib/docker/containers/*/*-json.log`
- `/opt/npm/data/logs/*_access.log` (Nginx proxy access logs)
- `/opt/npm/data/logs/*_error.log` (Nginx proxy error logs)

Not shipped by default:

- `/root/.northstar/npm-admin-credentials`
- `/var/log/northstar/cred-access.log`

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

If using `northstar observability enable`, include these additional actions:

- `cloudwatch:PutDashboard`
- `cloudwatch:DeleteDashboards`
- `cloudwatch:PutMetricAlarm`
- `cloudwatch:DeleteAlarms`
- `logs:PutMetricFilter`
- `logs:DeleteMetricFilter`

If you provide SNS action ARNs to `northstar observability enable`, also include:

- `sns:Publish` (scoped to your topic ARN(s))

Example (optional notifications):

```bash
sudo northstar observability enable \
  --alarm-action-arn arn:aws:sns:us-east-1:123456789012:npm-alerts \
  --ok-action-arn arn:aws:sns:us-east-1:123456789012:npm-alerts
```

### Troubleshooting permissions

- **Agent logs**: `sudo journalctl -u amazon-cloudwatch-agent.service -n 200 --no-pager`
- If you see `AccessDenied` or `UnauthorizedOperation`, attach an instance role with the permissions above and restart the agent: `sudo systemctl restart amazon-cloudwatch-agent.service`

### Disable CloudWatch shipping (optional)

If you do not want to send logs or metrics to CloudWatch:

```bash
sudo systemctl disable --now amazon-cloudwatch-agent.service
```

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
- `{instance_id}-docker`
- `{instance_id}-nginx-access`
- `{instance_id}-nginx-error`

### Metrics

Publish basic system metrics under the CloudWatch namespace:

**NorthstarCloudSolutions/System**

The AMI's default config collects:

- **mem_used_percent** – overall memory usage percentage

- **used_percent (for /)** – disk space used on the root filesystem

### Opt-in Alarms and Metric Filters

When `northstar observability enable` is run, the following alarms and metric filters are created:

**Metric Filters** (namespace: `NorthstarCloudSolutions/Operational`):

| Filter | Log Pattern | Metric |
|---|---|---|
| Backup failure | `NORTHSTAR_BACKUP status=failure` | `backup_failure_count` |
| Restore validation warning | `NORTHSTAR_RESTORE_VALIDATE status=warn` | `restore_validate_warn_count` |
| Certificate expiry warning | `NORTHSTAR_CERT_EXPIRY_WARN` | `cert_expiry_warn_count` |
| Health report failure | `NORTHSTAR_HEALTH_REPORT overall=fail` | `health_report_fail_count` |

**Alarms** (8 total):

| Alarm | Trigger | Namespace |
|---|---|---|
| Disk high | Root disk >= 85% for 15 min | `NorthstarCloudSolutions/System` |
| CPU iowait high | iowait >= 40% for 15 min | `NorthstarCloudSolutions/System` |
| Memory high | Memory >= 90% for 15 min | `NorthstarCloudSolutions/System` |
| Backup failure | Any backup failure event | `NorthstarCloudSolutions/Operational` |
| Restore validation warning | Post-restore validation warning/failure | `NorthstarCloudSolutions/Operational` |
| Certificate expiry warning | Certificate expiry warning logged | `NorthstarCloudSolutions/Operational` |
| Health report failure | Daily health report detects failing subsystem | `NorthstarCloudSolutions/Operational` |
| NPM unhealthy | EC2 status check failure | `AWS/EC2` |

**Dashboard** includes 5 widgets: CPU iowait, memory, disk, recent system logs, and operational events (showing backup, restore, cert, and health report events).

All alarms support optional SNS notification via `--alarm-action-arn` and `--ok-action-arn` flags.
