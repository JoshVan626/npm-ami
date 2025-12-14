# Security & Hardening

This AMI ships with a conservative security baseline applied out of the box.

---

## SSH configuration

- `PasswordAuthentication no`
- `PermitRootLogin no`
- `UsePAM yes`
- `Banner /etc/issue.net` – displays a legal/security notice

**Implications:**

- You **must** use SSH keys to access the instance.
- Logging in directly as `root` via SSH is disabled.
- You should SSH as `ubuntu` (or another user you configure) and use `sudo`.

---

## Firewall (UFW)

UFW is installed and configured to:

- Deny all incoming connections by default
- Allow all outgoing connections by default
- Allow only:

  - `22/tcp` – SSH
  - `80/tcp` – HTTP
  - `81/tcp` – NPM admin UI
  - `443/tcp` – HTTPS

Check rules:

```bash
sudo ufw status numbered
```

If you need to allow additional ports, use:

```bash
sudo ufw allow <port>/tcp comment 'your-service-name'
```

---

## Fail2ban

Fail2ban is configured with an `sshd` jail:

- Monitors `/var/log/auth.log`
- Bans IPs after repeated failed SSH logins
- Uses the `systemd` backend for better integration with Ubuntu 22.04

Check status:

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status sshd
```

### Fail2ban: Check Status and Unban an IP

Check fail2ban status:

```bash
sudo systemctl status fail2ban --no-pager
sudo fail2ban-client status
```

Check the SSH jail (commonly named `sshd`):

```bash
sudo fail2ban-client status sshd
```

If the jail name differs in your environment, list jails using `sudo fail2ban-client status`.

Unban a specific IP address:

```bash
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

Warning: ensure you still have valid SSH key access before changing bans. Prefer allowing only trusted IPs in your EC2 Security Group for port `22/tcp`.

---

## Sysctl hardening

A small set of IPv4 hardening options is applied via:

```bash
/etc/sysctl.d/99-brand-hardened.conf
```

These settings:

- Disable accepting/sending ICMP redirects
- Disable accepting source-routed packets
- Ignore ICMP echo broadcasts
- Enable reverse path filtering

They are chosen to be **conservative** and not break normal traffic.

---

## SSH host keys & machine identity

For AMI integrity:

- SSH host keys are removed during AMI creation
- Machine ID is reset

### SSH Host Key Regeneration

SSH host keys are regenerated on first boot via `cloud-init` so each instance launched from the AMI has unique host keys. If you reuse an Elastic IP address or DNS name, your SSH client may show a one-time “host key changed” warning on the first connection to the new instance. This is expected behavior and does not indicate compromise. Update your local `known_hosts` entry for the hostname/IP and reconnect.

On first boot of an instance:

- New SSH host keys are generated
- A new machine ID is created

This ensures that **each** EC2 instance launched from the AMI has unique cryptographic material and identity.
