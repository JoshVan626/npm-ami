<!-- docs/product-spec.md -->

# Nginx Proxy Manager Premium AMI – Product Specification (v1)

> **Product:** Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions

---

## 1. Overview

**Product name (working):**  
**Nginx Proxy Manager Premium AMI – Hardened Ubuntu 22.04**

**Owner / Brand:**  
Northstar Cloud Solutions (registered as an AWS Marketplace seller)

**High-level description**

This product is a hardened, ready-to-run AWS AMI that ships with:

- Ubuntu Server 22.04 LTS  
- Docker Engine + Docker Compose plugin  
- A preconfigured Nginx Proxy Manager (NPM) container using SQLite  

On first boot, the AMI automatically:

- Starts Nginx Proxy Manager as a Docker container via a systemd unit.  
- Initializes the NPM SQLite database.  
- Generates a strong random admin password.  
- Updates the admin user’s credential in the NPM database.  
- Displays the login URL and credentials in the SSH login banner (MOTD).

The result is a **self-contained reverse proxy appliance** that can be launched in minutes, with secure defaults and minimal manual configuration.

**Primary use:**

> Quickly and safely expose HTTP/HTTPS services running inside a VPC (on EC2, containers, etc.) behind a TLS-terminating reverse proxy with a GUI (Nginx Proxy Manager).

---

## 2. Target Customers

### 2.1 Primary persona – Solo devs / small engineering teams on AWS

- 1–10 engineers, often without a dedicated DevOps or platform engineer.  
- Run small to medium workloads primarily on EC2/ECS/Fargate.  
- Need a simple, GUI-based way to:
  - Terminate HTTPS
  - Manage reverse proxies and virtual hosts
  - Issue and renew Let’s Encrypt certificates  
- Prefer not to manually install and configure Nginx or maintain custom reverse proxy configs across environments.

### 2.2 Secondary persona – Small MSPs / consultants

- Manage several small customer environments in AWS.  
- Frequently need to stand up reverse proxies per client/VPC and provide secure remote access to customer apps.  
- Want a **repeatable, hardened “drop-in” proxy appliance**.  
- Prefer standardized deployment and documentation they can reuse for multiple clients.

### 2.3 Example use cases

- Exposing a small set of internal admin dashboards to the internet behind HTTPS and HTTP auth.  
- Serving multiple applications (e.g., `app1.example.com`, `app2.example.com`) from a single EC2 instance and IP.  
- Providing a secure reverse proxy in a private VPC for internal dashboards.  
- Acting as a central TLS terminator for services that do not support HTTPS natively.

---

## 3. Product Scope

### 3.1 In-scope features (v1)

#### Operating system & base stack

- Ubuntu Server 22.04 LTS (x86_64).  
- Docker Engine installed via Docker’s official APT repository.  
- Docker Compose plugin available as `docker compose`.

#### Nginx Proxy Manager stack

- NPM running as a Docker container pinned to a specific, tested version (e.g., `jc21/nginx-proxy-manager:<version>`).  
- SQLite used as the NPM database:
  - Database file located under `/opt/npm/data/`.  
- Data directories:
  - `/opt/npm/data` for NPM data (DB, configs).  
  - `/opt/npm/letsencrypt` for certificates.

#### Systemd integration (self-healing)

- `npm.service` systemd unit:
  - Depends on `docker.service`.  
  - Runs `docker compose up -d` in `/opt/npm`.  
- NPM container healthcheck configured via Docker Compose:
  - Periodically checks the UI endpoint (e.g., `http://localhost:81/login`).

#### First-boot automation

- One-time `npm-init.service` systemd unit that:
  - Waits for the NPM SQLite DB to become available.  
  - Generates a secure random admin password.  
  - Hashes the password using bcrypt.  
  - Updates the NPM `auth` table in the SQLite DB for the admin user (`admin@example.com`).  
  - Writes a login banner (MOTD snippet) containing:
    - Admin URL: `http://<instance-public-ip>:81`  
    - Username: `admin@example.com`  
    - Generated password  
  - Writes credentials to a root-only file on disk.  
  - Creates a marker file (e.g., `/var/lib/npm-init-complete`) so it never runs again on the same instance.

#### Security & hardening baseline

- SSH:
  - Key-based authentication only (`PasswordAuthentication no`).  
  - Root login disabled (`PermitRootLogin no`).  
  - No SSH user keys baked into the AMI; `authorized_keys` is empty at AMI creation so cloud-init can inject the customer’s key.  
- SSH host keys:
  - Pre-generated host keys removed at AMI build time.  
  - New host keys generated automatically on first boot of each instance.  
- Firewall:
  - UFW installed and enabled.  
  - Inbound allowed:
    - 22/tcp – SSH  
    - 80/tcp – HTTP  
    - 81/tcp – NPM admin GUI  
    - 443/tcp – HTTPS  
  - Default deny for other inbound connections.  
- System updates:
  - `unattended-upgrades` installed and enabled for security updates.

#### Ports & connectivity

- 22/tcp – SSH for admin access.  
- 80/tcp – HTTP for proxied apps and HTTP-01 challenges.  
- 81/tcp – NPM admin GUI.  
- 443/tcp – HTTPS for proxied apps.

#### Additional operational features (v1)

- **Built-in backup helper for NPM data**
  - `/usr/local/bin/npm-backup`:
    - Archives `/opt/npm/data` and `/opt/npm/letsencrypt` into a timestamped tarball in `/var/backups`.  
    - Optionally uploads the archive to S3 if configured (via `/etc/npm-backup.conf` and valid AWS credentials/role).  
    - Applies a simple local retention policy (keeps N recent backups).  
  - `/usr/local/bin/npm-restore`:
    - Restores from a specified backup archive into `/opt/npm/data` and `/opt/npm/letsencrypt`.  
    - Restarts the NPM stack and performs a basic health check.

- **CloudWatch logging integration**
  - CloudWatch Agent (or equivalent) pre-installed and configured to ship:
    - System logs (e.g., `/var/log/syslog`, `/var/log/auth.log`).  
    - NPM logs from a host-mounted directory (e.g., `/var/log/npm/*`).  
  - Log group naming convention such as:  
    - Log group: `/Northstar/npm`  
    - Log streams including the instance ID (e.g., `<instance-id>-system`, `<instance-id>-npm`).

- **NPM helper CLI tool**
  - `/usr/local/bin/npm-helper` with subcommands:
    - `show-admin`: Re-print the generated admin username and password from the stored credentials file.  
    - `rotate-admin`: Generate a new strong admin password, update the NPM DB, update the stored credentials file, and refresh the MOTD snippet.  
    - `status`: Display basic stack status:
      - `docker.service` / `npm.service` state  
      - Container status  
      - Last backup timestamp (if any backup tarballs exist in `/var/backups`)

### 3.2 Out-of-scope for v1

The v1 AMI **does NOT** provide:

- High availability or clustering (single-node only; no automatic failover).  
- Built-in WAF, IDS/IPS, or advanced layer-7 security features.  
- SSO/identity provider integration (OAuth2, SAML, etc.).  
- Automatic Route 53 or DNS record management.  
- Automated backup/restore beyond the provided helper tools and documented recommendations.  
- GUI or automation for OS-level management (firewall, system upgrades UI).  
- Load balancing across multiple NPM instances.  
- Multi-region deployment automation.

---

## 4. Technical Behavior

### 4.1 First boot behavior

When a new EC2 instance is launched from this AMI:

1. **OS & Docker startup**
   - Ubuntu 22.04 boots.  
   - `docker.service` is enabled and starts automatically.

2. **NPM stack initialization**
   - `npm.service` runs:
     - Working directory: `/opt/npm`.  
     - Command: `docker compose up -d`.  
   - NPM container starts and initializes:
     - The SQLite database in `/opt/npm/data/database.sqlite`.  
     - Default admin user `admin@example.com` and internal auth entries.

3. **Credential generation (one-time)**
   - `npm-init.service` (Type=oneshot) is triggered after `npm.service`:
     - Waits until the SQLite DB file exists and NPM tables are ready.  
     - Generates a secure random password.  
     - Creates a bcrypt hash of the password.  
     - Updates the NPM `auth` table:
       - Locates the admin user’s `id` in the `user` table.  
       - Updates `auth.secret` for that `user_id` where `type = 'password'`.  
     - Writes credentials to a root-only file (e.g., `/root/npm-admin-credentials.txt`).  
     - Writes an MOTD snippet showing the admin URL, user, and password.  
     - Creates a marker file (e.g., `/var/lib/npm-init-complete`) so it does not run again on this instance.

4. **Ready state**
   - NPM is listening on ports 80, 81, and 443.  
   - Admin credentials are unique to this instance.  
   - The instance is ready to be used as a reverse proxy.

### 4.2 Normal operation

- `docker.service` and `npm.service` are expected to be **active**.  
- `docker compose ps` in `/opt/npm` shows the NPM container running.  
- The NPM UI is reachable at `http://<instance-ip>:81`.  
- All configuration changes (hosts, SSL certs, etc.) are done via the NPM UI.  
- OS-level configuration changes are performed using standard Ubuntu tooling (`apt`, `ufw`, etc.).  
- Security patches are applied automatically via `unattended-upgrades` between AMI releases.

If the instance reboots:

- Docker starts.  
- `npm.service` brings up the NPM stack.  
- Admin credentials remain unchanged (since `npm-init.service` only runs once per instance).

### 4.3 Updates

**AMI owner responsibilities (Northstar Cloud Solutions):**

- Periodically:
  - Rebuild the AMI with:
    - Updated Ubuntu base image and packages (security patches).  
    - Updated Docker Engine versions as needed.  
    - Updated NPM container version (when stable and tested).  
  - Publish these as new AMI versions on AWS Marketplace.

**Customer responsibilities:**

- For existing instances:
  - Rely on `unattended-upgrades` for OS-level security patches.  
  - Optionally run manual `apt upgrade` as needed (respecting Docker guidance).  
  - Optionally pull a newer NPM container image at their own risk if they want to deviate from the pinned version.  

- For major upgrades:
  - Launch a new instance from a newer AMI version.  
  - Use the backup/restore tooling to migrate NPM configuration and data.

### 4.4 Backup & Restore (v1)

**Data locations:**

- `/opt/npm/data` – NPM configuration and SQLite DB.  
- `/opt/npm/letsencrypt` – TLS certificates and related data.

**Built-in backup tooling:**

- `/usr/local/bin/npm-backup`:
  - Creates a compressed archive of the data directories under `/var/backups` with a timestamped file name.  
  - Optionally uploads the archive to an S3 bucket or URI if the customer configures AWS credentials/role and target settings in `/etc/npm-backup.conf`.  
- `/usr/local/bin/npm-restore`:
  - Restores from a specified backup archive into `/opt/npm/data` and `/opt/npm/letsencrypt`.  
  - Restarts the NPM stack and verifies basic health.

**Recommended backup pattern:**

- For small environments:
  - Run `npm-backup` via a systemd timer (e.g., daily) and keep a rotation of backup files locally and optionally in S3.  
- For stricter environments:
  - Combine EBS snapshots with `npm-backup` for both volume-level and application-level backups.

**Restore workflow:**

1. Launch a new instance from the same AMI version (or a compatible newer version).  
2. Copy or attach the backup archive(s).  
3. Run `npm-restore` to rehydrate `/opt/npm/data` and `/opt/npm/letsencrypt`.  
4. Confirm that NPM UI, hosts, and certificates are available and functioning.

### 4.5 Onboarding & First-Login Experience

**MOTD banner:**

On first SSH login as `ubuntu`, the MOTD displays:

- A brief description of the product.  
- NPM admin URL: `http://<instance-ip>:81`.  
- Admin username and generated password.  
- A short onboarding checklist:

1. Log into NPM and immediately change the admin password.  
2. Configure your first Proxy Host.  
3. (Optional) Set up HTTPS with Let’s Encrypt.  
4. Configure periodic backups using `npm-backup`.

**Documentation alignment:**

- The AWS Marketplace “Usage Instructions” and external documentation mirror this checklist.  
- Docs provide step-by-step guidance for:
  - Launching the instance.  
  - Logging into NPM.  
  - Creating the first Proxy Host.  
  - Enabling HTTPS with Let’s Encrypt.  
  - Enabling and verifying automated backups.

---

## 5. Instance Sizing & Usage

### 5.1 Minimum supported instance type

- **Minimum:** `t3.micro`
  - Intended for labs, testing, or very low-traffic personal projects.  
  - Limitations: low memory and CPU can become a bottleneck under TLS-heavy or high-request workloads.

### 5.2 Recommended for production

- **Baseline production:** `t3.small`  
- **Higher loads / many sites:** `t3.medium` and above

### 5.3 Usage assumptions (initial, to be validated later)

- **t3.micro**
  - 1–3 low-traffic sites.  
  - Light usage, mostly internal or admin-only traffic.

- **t3.small**
  - 3–10 sites.  
  - Light to moderate traffic workloads.  
  - Occasional bursts acceptable.

- **t3.medium and above**
  - Higher concurrency and/or more TLS handshakes.  
  - Suitable for multiple customer-facing sites or several internal dashboards with more users.

CPU and memory usage are primarily driven by:

- Number and complexity of proxied hosts.  
- TLS termination load.  
- NPM UI usage (generally low impact).

---

## 6. Security & Hardening

### 6.1 SSH configuration

- `PasswordAuthentication no` – only SSH keys allowed.  
- `PermitRootLogin no` – root cannot log in over SSH.  
- Default login user: `ubuntu`.  
- No custom SSH keys pre-baked; cloud-init populates `~ubuntu/.ssh/authorized_keys` at first boot using the AWS key pair.

### 6.2 SSH host keys

- At AMI build time, all host keys under `/etc/ssh/ssh_host_*` are removed.  
- On first boot of a new instance, SSH host keys are regenerated:
  - Ensures each customer instance has unique SSH host keys.  
  - Avoids host key reuse across customers.

### 6.3 Firewall (UFW)

- UFW is installed and enabled.  
- Inbound rules allow:
  - 22/tcp – SSH  
  - 80/tcp – HTTP  
  - 81/tcp – NPM admin GUI  
  - 443/tcp – HTTPS  
- Default policy denies all other inbound connections.  
- Customers can add additional UFW rules as needed.

### 6.4 OS updates and security patches

- `unattended-upgrades` is installed and configured for security updates.  
- Customers can:
  - Rely on automatic security updates between AMI releases.  
  - Apply manual updates if required by their policies.

### 6.5 Container & NPM security

- NPM Docker image pinned to a specific version to avoid unexpected upstream changes.  
- Containers run under Docker’s default security model; no privileged containers used.  
- The default NPM admin account’s password is:
  - Generated at first boot per instance.  
  - Not stored in plaintext anywhere in the AMI.  
  - Only displayed in MOTD on the running instance and stored in a root-only credentials file.

### 6.6 Additional hardening (v1)

- **Fail2ban:**
  - `fail2ban` installed and enabled with a default SSH jail.  
  - Default policy: ban an IP after multiple failed SSH login attempts within a short time window, for a configurable ban duration.

- **Sysctl and OS hardening (lightweight):**
  - A small sysctl configuration file applied to improve network and kernel security with conservative, widely used settings (no aggressive tuning that could break workloads).

- **Clear identification:**
  - SSH login banner and documentation clearly identify the instance as the Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions and link to support/doc resources.

---

## 7. Support Policy

### 7.1 Support channels

- **Primary:** Email support via Northstar Cloud Solutions support channels.  
- **Optional future:** Dedicated form on the Northstar Cloud Solutions website.

### 7.2 Availability & response targets

- Availability:
  - Best-effort support during business hours:
    - Monday–Friday, 9am–5pm US Eastern.  
- Target response time:
  - Within 2 business days for initial responses.  
- No guaranteed SLA/Uptime or financial credits in v1.

### 7.3 Scope of support (included)

- Issues where:
  - The AMI instance fails to boot correctly on supported instance types.  
  - The NPM container fails to start when launched with standard Marketplace instructions.  
  - Admin credential generation appears broken (e.g., MOTD not showing password, login failures with generated password).  
  - Documentation or configuration examples are unclear or incorrect.

### 7.4 Out of scope (not included)

- General AWS support (VPC design, security groups, routing, etc.).  
- Troubleshooting of customer applications that sit behind NPM.  
- Deep performance tuning for heavy workloads.  
- Custom Nginx configuration beyond NPM’s standard capabilities.  
- Consulting on architectural design (multi-region, multi-account, etc.).

---

## 8. Pricing Strategy (Concept)

### 8.1 Pricing model

- **Type:** AMI-based hourly software charge on top of AWS infrastructure costs.  
- **Structure (v1):**
  - Flat hourly software fee per running instance.  
  - Same software fee across main instance families (e.g., t3, m5, etc.).  

**Licensing assumptions:**

- Unlimited number of proxied hosts per instance.  
- Unlimited number of users accessing NPM UI per instance.  
- No per-site, per-user, or per-request charges.

### 8.2 Positioning

- **Tier:** Low-to-mid tier vs other reverse proxy/security AMIs.  

**Justification:**

- Provides time savings and reduced misconfiguration risk.  
- Focuses on single-instance, non-HA deployments.  
- Does not include enterprise SLAs, clustering, or SSO at v1.

**Intro approach:**

- Launch at an attractive introductory hourly rate to encourage adoption and reviews.  
- Reassess pricing after:
  - Gathering real-world usage and feedback.  
  - Adding premium features (e.g., SSO integration, enhanced logging, additional hardening).

