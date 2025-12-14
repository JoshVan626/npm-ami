# Operations

This AMI includes a few opinionated tools and services to make NPM easier to
run in production.

---

## Systemd services

Key services:

- `docker.service` – Docker engine
- `npm.service` – NPM Docker stack
- `npm-init.service` – one-time first-boot initialization
- `npm-backup.timer` – daily backup timer
- `amazon-cloudwatch-agent.service` – CloudWatch log shipping

Basic commands:

```bash
# Check status
sudo systemctl status npm
sudo systemctl status docker
sudo systemctl status amazon-cloudwatch-agent

# View logs
sudo journalctl -u npm
sudo journalctl -u amazon-cloudwatch-agent

# Restart NPM stack
sudo systemctl restart npm
```

`npm.service` will retry automatically if `docker compose up -d` or the follow-up
container health check fails (e.g., transient network/pull issues). If the stack
is not coming up, check:

- `sudo systemctl status npm` for recent restart attempts
- `sudo journalctl -u npm` for compose output and container state summaries
- `docker compose ps` in `/opt/npm` to see per-container status

---

## CLI: npm-helper

`npm-helper` is installed under `/usr/local/bin`. It provides three main
subcommands:

### Show current admin credentials

```bash
sudo npm-helper show-admin
```

Outputs the current admin username/password stored in:

- `/root/npm-admin-credentials.txt`

### Rotate admin password

```bash
sudo npm-helper rotate-admin
```

What it does:

1. Waits for the NPM SQLite database to be ready.
2. Generates a new strong random password.
3. Updates the NPM `auth` table with the new bcrypt hash.
4. Writes the new credentials to `/root/npm-admin-credentials.txt`.
5. Updates the MOTD banner so new logins see the updated credentials.

Use this whenever you want to rotate the admin password without touching the
web UI.

### Status overview

```bash
sudo npm-helper status
```

Shows:

- Docker service status
- `npm` service status
- Container status from `docker compose ps`
- Last backup timestamp found under `/var/backups`

This is a quick way to check if the system is healthy.

---

## Logs & CloudWatch

The CloudWatch Agent is configured to ship:

- `/var/log/syslog`
- `/var/log/auth.log`

into a log group named:

```text
/Northstar/npm
```

with per-instance log streams (e.g. `{instance_id}-syslog`, `{instance_id}-auth`).

You can view these in:

- AWS Console → CloudWatch → Logs → Log groups → `/Northstar/npm`

This is useful for:

- SSH login attempts
- System service failures
- General OS-level troubleshooting

---

## Where NPM keeps its data

NPM runs in Docker and stores its state in:

- `/opt/npm/data` – configuration, SQLite DB
- `/opt/npm/letsencrypt` – TLS certificates

These paths are:

- Mounted into the NPM container
- Included in backup archives (`npm-backup` / `npm-restore`)
- Preserved across instance reboots
