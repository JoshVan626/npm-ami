#!/usr/bin/env bash
# Security Hardening Script
# Applies SSH hardening, UFW firewall, fail2ban, sysctl tuning, and SSH banner

set -Eeuo pipefail

# Print a helpful message on unexpected errors. (Expected validation failures are handled explicitly.)
trap 'echo "✗ Error: Script failed on line ${LINENO}. Aborting."; exit 1' ERR

# Determine repo root and ami-files path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AMI_FILES="$REPO_ROOT/ami-files"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Security Hardening"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Script directory: $SCRIPT_DIR"
echo "Repo root: $REPO_ROOT"
echo "AMI files directory: $AMI_FILES"
echo ""

# Verify ami-files directory exists
if [[ ! -d "$AMI_FILES" ]]; then
    echo "✗ Error: ami-files directory not found at $AMI_FILES"
    exit 1
fi

# Step 1: Copy security config files
echo "[1/7] Copying security configuration files..."

# Copy fail2ban config
if [[ ! -f "$AMI_FILES/etc-fail2ban/jail.local" ]]; then
    echo "✗ Error: jail.local not found at $AMI_FILES/etc-fail2ban/jail.local"
    exit 1
fi
cp "$AMI_FILES/etc-fail2ban/jail.local" "/etc/fail2ban/jail.local"
chown root:root "/etc/fail2ban/jail.local"
chmod 0644 "/etc/fail2ban/jail.local"
echo "  ✓ Copied fail2ban jail.local"

# Copy sysctl config
if [[ ! -f "$AMI_FILES/etc-sysctl.d/99-brand-hardened.conf" ]]; then
    echo "✗ Error: 99-brand-hardened.conf not found at $AMI_FILES/etc-sysctl.d/99-brand-hardened.conf"
    exit 1
fi
cp "$AMI_FILES/etc-sysctl.d/99-brand-hardened.conf" "/etc/sysctl.d/99-brand-hardened.conf"
chown root:root "/etc/sysctl.d/99-brand-hardened.conf"
chmod 0644 "/etc/sysctl.d/99-brand-hardened.conf"
echo "  ✓ Copied sysctl configuration"

# Copy SSH banner
if [[ ! -f "$AMI_FILES/etc/issue.net" ]]; then
    echo "✗ Error: issue.net not found at $AMI_FILES/etc/issue.net"
    exit 1
fi
cp "$AMI_FILES/etc/issue.net" "/etc/issue.net"
chown root:root "/etc/issue.net"
chmod 0644 "/etc/issue.net"
echo "  ✓ Copied SSH banner (issue.net)"

echo "✓ Security configuration files copied"

# Step 2: SSH hardening
echo ""
echo "[2/7] Hardening SSH configuration..."

SSH_CONFIG="/etc/ssh/sshd_config"

################################################################################
# SSH SAFETY GUARDRAILS (to prevent lockout incidents)
#
# - Always back up /etc/ssh/sshd_config *before* editing.
#   - We keep a stable backup at /etc/ssh/sshd_config.bak
#   - If .bak already exists, we also snapshot it to a timestamped file so we
#     never lose the last known-good copy.
# - Never restart/reload SSH unless `sshd -t` validates the config.
#   - If validation fails, we automatically restore the backup, re-validate, and
#     abort (fail fast).
# - Ensure host keys exist before any SSH restart (`ssh-keygen -A`).
# - Restart SSH safely and verify it is running (`systemctl is-active ssh`).
#   - On failure, restore the backup config and retry once, then abort.
################################################################################

ssh_timestamp() { date +"%Y%m%d-%H%M%S"; }

backup_sshd_config() {
    # Always create/update the primary .bak from the pre-edit config.
    # If a .bak already exists, preserve it with a timestamp to avoid losing the
    # last known-good backup.
    if [[ -f "${SSH_CONFIG}.bak" ]]; then
        local ts
        ts="$(ssh_timestamp)"
        cp -a "${SSH_CONFIG}.bak" "${SSH_CONFIG}.bak.${ts}"
        echo "  Preserved existing backup: ${SSH_CONFIG}.bak.${ts}"
    fi

    cp -a "$SSH_CONFIG" "${SSH_CONFIG}.bak"
    echo "  Created backup: ${SSH_CONFIG}.bak"
}

restore_sshd_config() {
    echo "  Restoring SSH config from backup: ${SSH_CONFIG}.bak"
    cp -a "${SSH_CONFIG}.bak" "$SSH_CONFIG"
}

validate_sshd_config_or_restore_and_abort() {
    # Do NOT let `set -e` exit before we restore; handle validation explicitly.
    if sshd -t; then
        echo "  ✓ sshd_config validated (sshd -t)"
        return 0
    fi

    echo "✗ ERROR: SSH configuration validation failed (sshd -t)."
    echo "         Restoring the previous configuration to prevent SSH lockout."
    restore_sshd_config

    if sshd -t; then
        echo "  ✓ Restored config validates. Aborting to avoid applying a broken SSH config."
        exit 1
    fi

    echo "✗ ERROR: Restored SSH config STILL fails validation (sshd -t)."
    echo "         Manual intervention required. Aborting."
    exit 1
}

safe_restart_ssh_or_abort() {
    # Ensure host keys exist before attempting restart (required for sshd to start).
    ssh-keygen -A

    # Restart SSH (do not reload) and verify it's active.
    systemctl restart ssh
    if systemctl is-active --quiet ssh; then
        echo "✓ SSH service restarted and is active"
        return 0
    fi

    echo "✗ ERROR: SSH service is not active after restart."
    echo "         Attempting automatic recovery: restore backup config and retry once."

    restore_sshd_config
    ssh-keygen -A

    # Re-validate before retrying the restart.
    if ! sshd -t; then
        echo "✗ ERROR: Restored SSH config failed validation (sshd -t). Aborting."
        exit 1
    fi

    systemctl restart ssh
    if systemctl is-active --quiet ssh; then
        echo "✓ SSH recovered: service restarted and is active after restoring backup"
        return 0
    fi

    echo "✗ ERROR: SSH service still not active after recovery attempt. Aborting."
    exit 1
}

# Backup SSH config before any edits (always).
backup_sshd_config

# Function to set SSH directive
set_ssh_directive() {
    local directive="$1"
    local value="$2"
    local pattern="^[[:space:]]*#?[[:space:]]*${directive}[[:space:]]+"
    
    if grep -qE "$pattern" "$SSH_CONFIG"; then
        # Replace existing directive (commented or not)
        sed -i "s|${pattern}.*|${directive} ${value}|" "$SSH_CONFIG"
        echo "    Updated: ${directive} ${value}"
    else
        # Append new directive
        echo "${directive} ${value}" >> "$SSH_CONFIG"
        echo "    Added: ${directive} ${value}"
    fi
}

# Apply SSH hardening directives
# Conservative defaults:
# - Keep port 22 available (do not disable it). If a custom Port is already set
#   and does not include 22, we add an additional "Port 22" line rather than
#   overwriting existing ports.
# - Ensure Public Key auth stays enabled (preferred for secure access).
if grep -qE '^[[:space:]]*#?[[:space:]]*Port[[:space:]]+22([[:space:]]+|$)' "$SSH_CONFIG"; then
    echo "    Port 22 already present"
elif grep -qE '^[[:space:]]*#?[[:space:]]*Port[[:space:]]+' "$SSH_CONFIG"; then
    echo "    Adding: Port 22 (in addition to existing Port directives)"
    echo "Port 22" >> "$SSH_CONFIG"
else
    set_ssh_directive "Port" "22"
fi

set_ssh_directive "PubkeyAuthentication" "yes"
set_ssh_directive "PasswordAuthentication" "no"
set_ssh_directive "PermitRootLogin" "no"
set_ssh_directive "UsePAM" "yes"
set_ssh_directive "Banner" "/etc/issue.net"

echo "  Validating SSH configuration..."
validate_sshd_config_or_restore_and_abort

echo "✓ SSH configuration hardened and validated"

# Step 3: Apply sysctl settings
echo ""
echo "[3/7] Applying sysctl settings..."

if sysctl -p /etc/sysctl.d/99-brand-hardened.conf > /dev/null 2>&1; then
    echo "✓ Sysctl settings applied successfully"
else
    echo "⚠ Warning: Some sysctl settings may not have applied (this is usually safe)"
fi

# Step 4: Configure UFW
echo ""
echo "[4/7] Configuring UFW firewall..."

# Ensure UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "  Installing UFW..."
    apt-get update
    apt-get install -y ufw
fi

# Reset UFW to defaults (in case it was partially configured)
ufw --force reset > /dev/null 2>&1 || true

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow required ports
echo "  Configuring firewall rules..."
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 81/tcp comment 'NPM Admin UI'
ufw allow 443/tcp comment 'HTTPS'

# Enable UFW non-interactively
ufw --force enable

echo "✓ UFW configured and enabled"
echo ""
echo "UFW Status:"
ufw status numbered

# Step 5: Enable and restart fail2ban
echo ""
echo "[5/7] Configuring fail2ban..."

# Ensure fail2ban is installed
if ! command -v fail2ban-server &> /dev/null; then
    echo "  Installing fail2ban..."
    apt-get update
    apt-get install -y fail2ban
fi

# Enable and restart fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

# Verify fail2ban is active
if systemctl is-active --quiet fail2ban; then
    echo "✓ fail2ban service is active"
else
    echo "⚠ Warning: fail2ban service may not be running properly"
fi

# Step 6: Restart SSH safely (validated config + host keys + active check)
echo ""
echo "[6/7] Restarting SSH service safely..."

echo "⚠ WARNING: SSH service will be restarted."
echo "           Your current SSH session may be disconnected."
echo "           Wait a few seconds before attempting to reconnect."
echo ""

# Never restart SSH unless the config validates.
echo "  Re-validating SSH configuration immediately before restart..."
validate_sshd_config_or_restore_and_abort

safe_restart_ssh_or_abort

# Step 7: Remove existing SSH host keys (for AMI uniqueness)
echo ""
echo "[7/7] Removing SSH host keys..."

# Remove all SSH host keys so instances launched from the AMI generate unique keys.
# IMPORTANT: We do this *after* verifying SSH can restart safely to prevent lockout.
rm -f /etc/ssh/ssh_host_*

echo "✓ SSH host keys removed"
echo "  Note: Host keys will be regenerated on first boot by cloud-init or system services"
echo "        This ensures each instance has unique SSH host keys"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Security hardening completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo ""
echo "Configuration files copied:"
echo "  - /etc/fail2ban/jail.local"
echo "  - /etc/sysctl.d/99-brand-hardened.conf"
echo "  - /etc/issue.net (SSH banner)"
echo ""
echo "SSH hardening applied:"
echo "  - PasswordAuthentication: no"
echo "  - PermitRootLogin: no"
echo "  - UsePAM: yes"
echo "  - Banner: /etc/issue.net"
echo ""
echo "Firewall (UFW) configured:"
echo "  - Port 22/tcp (SSH) - allowed"
echo "  - Port 80/tcp (HTTP) - allowed"
echo "  - Port 81/tcp (NPM Admin UI) - allowed"
echo "  - Port 443/tcp (HTTPS) - allowed"
echo "  - UFW enabled"
echo ""
echo "Fail2ban:"
if systemctl is-active --quiet fail2ban; then
    echo "  - Service enabled and active"
else
    echo "  - Service enabled (status unknown)"
fi
echo ""
echo "SSH host keys:"
echo "  - Removed (will be regenerated on first boot)"
echo ""
echo "Sysctl settings:"
echo "  - Network hardening applied"
echo ""
echo "Next steps:"
echo "  - Run 04-cloudwatch-setup.sh to configure logging"
echo ""

exit 0

