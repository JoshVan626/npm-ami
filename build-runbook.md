<!-- docs/build-runbook.md -->

# Build Runbook – Nginx Proxy Manager Premium AMI

> This document describes how to go from **nothing** to a prepared set of files and scripts that can be applied to an Ubuntu 22.04 EC2 instance to create a “golden image” for the Nginx Proxy Manager Premium AMI.

The actual AWS Marketplace registration and AMI publishing come later. This runbook focuses on **what goes inside the instance**.

---

## 1. Goals

By following this runbook you will:

1. Create a local repo structure for the project.  
2. Define all files that must exist inside the AMI (Docker, systemd, scripts, configs).  
3. Implement these files using Cursor/AI assistance.  
4. Have a clear sequence of commands to run on an EC2 “builder” instance to turn a vanilla Ubuntu 22.04 machine into the final AMI root volume.  
5. Have a basic test checklist to validate the behavior.

---

## 2. Prerequisites

- You have a local development environment with:
  - Git
  - A code editor (Cursor)
- You have the following docs in place:
  - `docs/product-spec.md` – full product spec.
  - `docs/build-runbook.md` – this file.

> **Note:** You do **not** need an AWS account yet to work through the repo structure and file content. You only need AWS later when applying these files onto a real EC2 instance.

---

## 3. Repository Layout

Create a repo named something like `npm-premium-ami` with this structure:

```text
npm-premium-ami/
├─ docs/
│  ├─ product-spec.md
│  ├─ build-runbook.md
├─ ami-files/
│  ├─ opt-npm/
│  │  ├─ docker-compose.yml
│  ├─ usr-local-bin/
│  │  ├─ npm-init.py
│  │  ├─ npm-helper
│  │  ├─ npm-backup
│  │  ├─ npm-restore
│  ├─ etc-systemd-system/
│  │  ├─ npm.service
│  │  ├─ npm-init.service
│  │  ├─ npm-backup.service
│  │  ├─ npm-backup.timer
│  ├─ etc-fail2ban/
│  │  ├─ jail.local
│  ├─ etc-sysctl.d/
│  │  ├─ 99-brand-hardened.conf
│  ├─ etc/
│  │  ├─ issue.net
│  │  ├─ npm-backup.conf
│  ├─ opt-aws/
│  │  ├─ amazon-cloudwatch-agent/
│  │  │  ├─ amazon-cloudwatch-agent.json
├─ scripts/
│  ├─ 00-base-packages.sh
│  ├─ 01-install-docker.sh
│  ├─ 02-setup-npm-stack.sh
│  ├─ 03-security-hardening.sh
│  ├─ 04-cloudwatch-setup.sh
│  ├─ 05-cleanup-for-ami.sh
```

**Note on MOTD script (`/etc/update-motd.d/50-npm-info`):**

The MOTD script that displays login credentials is **not** shipped as a static file in `ami-files/etc-update-motd.d/`. Instead, it is dynamically generated on first boot by `npm-init.py` using the `npm_common.build_motd_script()` function. This script is created at `/etc/update-motd.d/50-npm-info` after the admin password is generated and includes the instance IP address and generated credentials. The file only exists after first-boot initialization completes.

---

## 4. Building the AMI

### Prerequisites

- AWS account with EC2 access
- EC2 instance running Ubuntu 22.04 LTS (builder instance)
- SSH access to the builder instance
- Git installed on builder instance (or transfer files via SCP)

### Step-by-Step Build Process

1. **Launch a builder instance:**
   - Launch a fresh Ubuntu 22.04 LTS EC2 instance
   - Recommended: `t3.medium` or larger for faster builds
   - Ensure security group allows SSH (port 22) from your IP
   - Note the instance's public IP address

2. **Transfer the repository to the builder instance:**
   
   Option A: Clone from Git (if repository is in a Git repo):
   ```bash
   ssh ubuntu@<builder-instance-ip>
   git clone <repository-url>
   cd npm-ami
   ```
   
   Option B: Transfer files via SCP:
   ```bash
   # From your local machine
   scp -r npm-ami ubuntu@<builder-instance-ip>:~/
   ssh ubuntu@<builder-instance-ip>
   cd npm-ami
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh
   ```

4. **Run build scripts in order:**
   
   Each script should be run as root (use `sudo`):
   
   ```bash
   # Script 00: Install base packages
   sudo ./scripts/00-base-packages.sh
   
   # Script 01: Install Docker
   sudo ./scripts/01-install-docker.sh
   
   # Script 02: Setup NPM stack
   sudo ./scripts/02-setup-npm-stack.sh
   
   # Script 03: Security hardening
   sudo ./scripts/03-security-hardening.sh
   
   # Script 04: CloudWatch setup
   sudo ./scripts/04-cloudwatch-setup.sh

   # Script 06: Validation gate (recommended before cleanup/imaging)
   # This fails fast on broken systemd units, missing payload files, or Python helper syntax errors.
   sudo ./scripts/06-validate.sh
   
   # Script 05: Cleanup for AMI (WARNING: prepares for snapshot)
   sudo ./scripts/05-cleanup-for-ami.sh
   ```
   
   **Important:** 
   - Run scripts in order (00 through 05), and run the validation gate before cleanup/imaging
   - Wait for each script to complete before running the next
   - Review output for any errors or warnings
   - Script 05 will prompt for confirmation before proceeding

5. **Verify the build:**
   
   After running all scripts, verify key components:
   
   ```bash
   # Check services are enabled
   sudo systemctl list-unit-files | grep -E "npm|docker|cloudwatch"
   
   # Verify files are in place
   ls -la /opt/npm/docker-compose.yml
   ls -la /usr/local/bin/npm-*
   ls -la /etc/systemd/system/npm*
   
   # Check CloudWatch config
   cat /opt/aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json
   ```

6. **Create the AMI snapshot:**
   
   **Option A: Using AWS Console:**
   - Go to EC2 → Instances
   - Select the builder instance
   - Actions → Image and templates → Create image
   - Enter image name and description
   - Click "Create image"
   
   **Option B: Using AWS CLI:**
   ```bash
   aws ec2 create-image \
     --instance-id <instance-id> \
     --name "npm-hardened-edition-ubuntu22-<version>" \
     --description "Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions"
   ```

7. **Wait for AMI creation:**
   - AMI creation typically takes 5-15 minutes
   - Monitor in EC2 → AMIs
   - Wait until status is "available"

### What to Expect

- **Script 00:** Takes 5-10 minutes (package installation)
- **Script 01:** Takes 3-5 minutes (Docker installation)
- **Script 02:** Takes 1-2 minutes (file copying and systemd setup)
- **Script 03:** Takes 2-3 minutes (security configuration, may disconnect SSH briefly)
- **Script 04:** Takes 2-3 minutes (CloudWatch Agent installation)
- **Script 05:** Takes 1-2 minutes (cleanup)

**Total build time:** Approximately 15-25 minutes

### Troubleshooting Build Issues

- **Script fails:** Check the error message, fix the issue, and re-run the script
- **SSH disconnects during script 03:** This is normal (SSH service reload). Reconnect and continue
- **Package installation fails:** Check internet connectivity and AWS region availability
- **Docker installation fails:** Verify the builder instance has internet access
- **Permission errors:** Ensure scripts are executable (`chmod +x scripts/*.sh`)

---

## 5. Testing the AMI

After creating the AMI, you **must** test it before publishing:

1. **Launch a test instance from the AMI:**
   - Use a different instance than the builder
   - Use `t3.small` or larger for testing
   - Configure security group to allow ports 22, 80, 81, 443

2. **Follow the testing checklist:**
   - See [`docs/testing-checklist.md`](docs/testing-checklist.md) for comprehensive validation steps
   - Verify first boot works correctly
   - Test all functionality
   - Verify security hardening

3. **Fix any issues found:**
   - Update scripts or configurations as needed
   - Rebuild the AMI
   - Re-test until all checks pass

---

## Minimal Release Checklist (pre-release and release)

Use this checklist to reduce regressions and ensure traceability before any Marketplace submission.

- (Optional for RC, required for release) Tag the git commit (example: `v1.0.0`).
- Run build scripts on a fresh Ubuntu 22.04 builder instance:
  - `sudo ./scripts/00-base-packages.sh`
  - `sudo ./scripts/01-install-docker.sh`
  - `sudo ./scripts/02-setup-npm-stack.sh`
  - `sudo ./scripts/03-security-hardening.sh`
  - `sudo ./scripts/04-cloudwatch-setup.sh`
  - `sudo ./scripts/06-validate.sh`
  - `sudo ./scripts/05-cleanup-for-ami.sh`
- Bake the AMI.
- Launch test instances from the baked AMI:
  - Test A: **no IAM role attached** (CloudWatch optional; app must still work)
  - Test B: **IAM role attached** (CloudWatch logs/metrics should publish)
- Run smoke tests (see `docs/testing-checklist.md` → Smoke Test Checklist).
- Record build details (version/date/git SHA/pinned image tag/AMI IDs) in your internal release notes and AWS Marketplace metadata.

## 6. Next Steps

Once the AMI is built and tested:

1. **Document the AMI version:**
   - Note the AMI ID
   - Document any customizations or changes
   - Update version information

2. **Prepare for AWS Marketplace:**
   - Review AWS Marketplace requirements
   - Prepare product listing content
   - Set up seller account (if not already done)
   - Complete security and compliance documentation

3. **Publish the AMI:**
   - Follow AWS Marketplace publishing process
   - Submit for review
   - Address any feedback

---

## 7. Maintenance

For future AMI versions:

1. Update NPM Docker image version (if needed)
2. Update base packages and security patches
3. Apply any bug fixes or improvements
4. Rebuild following this runbook
5. Test thoroughly using the testing checklist
6. Publish new AMI version
