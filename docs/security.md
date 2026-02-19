# Security & Hardening

This AMI ships with a conservative security baseline applied out of the box.

---

## SSH configuration

- `PasswordAuthentication no`
- `PermitRootLogin no`
- `PubkeyAuthentication yes`
- `UsePAM yes`
- `Banner /etc/issue.net` – displays a legal/security notice

**Implications:**

- You **must** use SSH keys to access the instance.
- Logging in directly as `root` via SSH is disabled.
- You should SSH as `ubuntu` (or another user you configure) and use `sudo`.
- Initial admin credentials are stored in `/root/.northstar/npm-admin-credentials` (root-only, `0600`). Retrieve them with `sudo npm-helper show-creds` and rotate the password after first login.

---

## Firewall (UFW)

UFW is installed and configured to:

- Deny all incoming connections by default
- Allow all outgoing connections by default
- Allow only:

  - `22/tcp` – SSH
  - `80/tcp` – HTTP
  - `443/tcp` – HTTPS

In your **EC2 security group**, restrict `22/tcp` (SSH) and `81/tcp` (NPM Admin UI) to your admin IP(s) or trusted CIDR ranges. Avoid `0.0.0.0/0` for admin ports.


Port `81/tcp` (NPM Admin UI) is **restricted by default**. Do **not** expose it publicly; allowlist a single trusted IP or use an SSH tunnel. To allow access from a trusted IP:

```bash
sudo npm-helper admin-access enable --cidr <your-ip>/32
```

Disable the allowlist when finished:

```bash
sudo npm-helper admin-access disable
```

Do **not** expose port 81 to the public internet; use an SSH tunnel or a temporary single-IP allowlist.

SSH tunnel example:

```bash
ssh -i /path/to/key.pem -L 8181:localhost:81 ubuntu@<instance-public-ip>
```

Then open `http://localhost:8181` in your browser.

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

---

## Security Maintenance Policy

- The AMI base OS and Docker/NPM stack are periodically rebuilt (for example, on a roughly monthly cadence or as practical) to incorporate upstream security fixes and tested changes.
- Critical vulnerabilities in the base OS or pinned NPM container image may result in out-of-band AMI refreshes when practical, but there is no guaranteed timeline for specific CVEs.
- Older AMI versions are not guaranteed to receive fixes; for the best security posture, prefer the latest Marketplace version and plan to rotate instances to newer images over time.
- Between AMI releases, OS-level security updates on running instances rely on Ubuntu's `unattended-upgrades` and any additional patching practices you apply.
- Security maintenance and support are provided on a best-effort basis only; no formal SLA or uptime guarantee is offered.

---

## Compliance Mapping

This section maps the AMI's built-in hardening controls to the **CIS Ubuntu Linux 22.04 LTS Benchmark v1.0.0**. Use this as evidence when evaluating the AMI against your organization's compliance requirements.

> **Disclaimer:** This mapping is provided as guidance. Northstar Cloud Solutions LLC does not certify CIS compliance on your behalf. Customers should run their own CIS-CAT assessments or equivalent audits against running instances and apply any additional controls required by their security policies.

### SSH Server Configuration

| AMI Control | Configuration Source | CIS Benchmark Section | Status |
|---|---|---|---|
| `PasswordAuthentication no` | `/etc/ssh/sshd_config` | 5.2.6 -- Ensure SSH password authentication is disabled | Enforced at bake time |
| `PermitRootLogin no` | `/etc/ssh/sshd_config` | 5.2.10 -- Ensure SSH root login is disabled | Enforced at bake time |
| `PubkeyAuthentication yes` | `/etc/ssh/sshd_config` | 5.2.5 -- Ensure SSH access is configured | Enforced at bake time |
| `UsePAM yes` | `/etc/ssh/sshd_config` | 5.2.17 -- Ensure SSH PAM is enabled | Enforced at bake time |
| `Banner /etc/issue.net` | `/etc/ssh/sshd_config` | 1.7.1 -- Ensure message of the day is configured properly; 5.2.16 -- Ensure SSH warning banner is configured | Enforced at bake time |
| Unique SSH host keys per instance | `cloud-init` (`99-northstar-sshkeys.cfg`) | 5.2.1 -- Ensure permissions on /etc/ssh/sshd_config are configured | Regenerated on first boot |

### Firewall (UFW)

| AMI Control | Configuration Source | CIS Benchmark Section | Status |
|---|---|---|---|
| Default deny incoming | UFW policy (`ufw default deny incoming`) | 3.5.1.7 -- Ensure ufw default deny firewall policy | Enforced at bake time |
| Allow only 22/tcp, 80/tcp, 443/tcp | UFW rules | 3.5.1.4 -- Ensure ufw firewall rules exist for all open ports | Enforced at bake time |
| Port 81/tcp restricted by default | UFW + `npm-helper admin-access` | 3.5.1.7 -- Ensure ufw default deny firewall policy | Enforced at bake time; admin opt-in required |
| UFW enabled and active | `ufw --force enable` | 3.5.1.1 -- Ensure ufw is installed; 3.5.1.3 -- Ensure ufw service is enabled | Enforced at bake time |

### Network Parameters (sysctl)

| AMI Control | Configuration Source | CIS Benchmark Section | Status |
|---|---|---|---|
| `net.ipv4.conf.all.accept_redirects = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.2 -- Ensure ICMP redirects are not accepted | Enforced at bake time |
| `net.ipv4.conf.default.accept_redirects = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.2 -- Ensure ICMP redirects are not accepted | Enforced at bake time |
| `net.ipv4.conf.all.send_redirects = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.2 -- Ensure ICMP redirects are not sent | Enforced at bake time |
| `net.ipv4.conf.default.send_redirects = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.2 -- Ensure ICMP redirects are not sent | Enforced at bake time |
| `net.ipv4.conf.all.accept_source_route = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.1 -- Ensure source routed packets are not accepted | Enforced at bake time |
| `net.ipv4.conf.default.accept_source_route = 0` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.1 -- Ensure source routed packets are not accepted | Enforced at bake time |
| `net.ipv4.icmp_echo_ignore_broadcasts = 1` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.5 -- Ensure broadcast ICMP requests are ignored | Enforced at bake time |
| `net.ipv4.conf.all.rp_filter = 1` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.7 -- Ensure Reverse Path Filtering is enabled | Enforced at bake time |
| `net.ipv4.conf.default.rp_filter = 1` | `/etc/sysctl.d/99-brand-hardened.conf` | 3.3.7 -- Ensure Reverse Path Filtering is enabled | Enforced at bake time |

### Defense-in-Depth (supplementary controls)

| AMI Control | Configuration Source | CIS Benchmark Section | Status |
|---|---|---|---|
| fail2ban `sshd` jail (5 retries / 10 min window / 1 hr ban) | `/etc/fail2ban/jail.local` | Supplements 5.2.x SSH controls | Enforced at bake time |
| `unattended-upgrades` enabled | Ubuntu default + AMI configuration | 1.9 -- Ensure updates, patches, and additional security software are installed | Enabled by default |
| Admin credentials stored root-only (`0600`) | `/root/.northstar/npm-admin-credentials` | N/A -- defense-in-depth credential protection | Enforced at first boot |
| Optional Secrets Manager integration | `npm-init.py` + IAM role | N/A -- enterprise governance enhancement | Best-effort; requires IAM permissions |

### Runtime Compliance Verification

To verify that hardening controls are still applied on a running instance, use the compliance report command:

```bash
sudo npm-helper compliance-report
sudo npm-helper compliance-report --json
```

This checks SSH configuration, UFW state, sysctl parameters, and fail2ban status against the CIS mappings above and reports pass/fail for each control. The `--json` output can be attached to audit evidence packs. See [`docs/operations.md`](./operations.md) for details.

### Customer-Owned Controls

The following CIS controls depend on customer configuration and are outside the AMI baseline:

- **3.5.1.4** -- Additional firewall rules beyond the defaults (e.g., restricting SSH to specific CIDRs) are the customer's responsibility via EC2 Security Groups and UFW.
- **5.2.4** -- Restricting SSH access to specific users/groups (`AllowUsers`/`AllowGroups`) is customer-configured.
- **5.4.x** -- User account and password policies for any additional OS users created by the customer.
- **6.1.x / 6.2.x** -- File and directory permission auditing beyond the AMI defaults.
