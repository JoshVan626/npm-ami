#!/usr/bin/env bash
# Base Package Installation Script
# Installs core packages and dependencies needed for NPM Premium AMI on Ubuntu 22.04

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Base Package Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Update package lists
echo "[1/4] Updating package lists..."
apt-get update

echo ""
echo "[2/4] Upgrading existing packages..."
apt-get -y upgrade

# Step 2: Install base packages
echo ""
echo "[3/4] Installing base packages..."

apt-get install -y \
    curl \
    git \
    ufw \
    fail2ban \
    unattended-upgrades \
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
echo "[4/4] Installing Python bcrypt..."

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
echo ""
echo "Next steps:"
echo "  - Run 01-install-docker.sh to install Docker"
echo ""

exit 0

