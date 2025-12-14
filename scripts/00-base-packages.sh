#!/usr/bin/env bash
# Base Package Installation Script
# Installs core packages and dependencies needed for NPM Premium AMI on Ubuntu 22.04

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Base Package Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Update package lists
echo "[1/5] Updating package lists..."
apt-get update

echo ""
echo "[2/5] Upgrading existing packages..."
apt-get -y upgrade

# Step 2: Install base packages
echo ""
echo "[3/5] Installing base packages..."

apt-get install -y \
    curl \
    git \
    ufw \
    fail2ban \
    unattended-upgrades \
    cloud-init \
    python3 \
    python3-pip \
    sqlite3 \
    awscli \
    ca-certificates \
    gnupg \
    lsb-release

echo "✓ Base packages installed successfully"

# Step 3: Install Python bcrypt
echo ""
echo "[4/5] Installing Python bcrypt..."

BCRYPT_METHOD=""

# Try installing via apt first
if apt-get install -y python3-bcrypt 2>/dev/null; then
    echo "✓ python3-bcrypt installed via apt"
    BCRYPT_METHOD="apt"
else
    echo "  python3-bcrypt not available via apt, using pip instead..."
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Install bcrypt via pip
    python3 -m pip install bcrypt --quiet
    
    echo "✓ bcrypt installed via pip"
    BCRYPT_METHOD="pip"
fi

if [[ -z "$BCRYPT_METHOD" ]]; then
    echo "✗ Error: Failed to install bcrypt"
    exit 1
fi

# Step 4: Configure unattended-upgrades
echo ""
echo "Configuring unattended-upgrades..."

# Ensure unattended-upgrades is enabled
systemctl enable unattended-upgrades

# Configure automatic security updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
APT::Unattended-Upgrade::Remove-Unused-Dependencies "true";
APT::Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "✓ unattended-upgrades configured"
echo "  - Automatic security updates enabled"
echo "  - Automatic reboot disabled (manual reboot required)"

# Step 5: Validate cloud-init installation and enablement (required for SSH key rotation)
echo ""
echo "[5/5] Verifying cloud-init is installed and enabled..."

if ! command -v cloud-init >/dev/null 2>&1; then
    echo "✗ Error: cloud-init is not installed even after package install. Aborting."
    exit 1
fi

# Ensure the service is enabled for first-boot execution.
if ! systemctl is-enabled --quiet cloud-init 2>/dev/null; then
    echo "  Enabling cloud-init service..."
    if ! systemctl enable cloud-init >/dev/null 2>&1; then
        echo "✗ Error: Failed to enable cloud-init service. Aborting."
        exit 1
    fi
fi

echo "✓ cloud-init is installed and enabled"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Base package installation completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installed packages:"
echo "  - curl, git, ufw, fail2ban, unattended-upgrades"
echo "  - python3, python3-pip, sqlite3"
echo "  - awscli, ca-certificates, gnupg, lsb-release"
echo "  - bcrypt (via $BCRYPT_METHOD)"
echo "  - cloud-init"
echo ""
echo "Next steps:"
echo "  - Run 01-install-docker.sh to install Docker"
echo ""

exit 0

