#!/usr/bin/env bash
# AMI Cleanup Script
# Prepares the instance for AMI creation by removing instance-specific data

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AMI Cleanup - Preparing Instance for AMI Creation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠ WARNING: This script should ONLY be run right before creating an AMI snapshot."
echo "           It will remove instance-specific data, logs, and history."
echo "           Do NOT run this on a production instance you plan to continue using."
echo ""
read -p "Are you sure you want to proceed? (type 'yes' to continue): " confirmation
if [[ "$confirmation" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi
echo ""

# Step 1: Stop services
echo "[1/7] Stopping services..."

# Stop NPM service
if systemctl is-active --quiet npm 2>/dev/null; then
    systemctl stop npm 2>/dev/null || true
    echo "  ✓ Stopped npm service"
else
    echo "  ℹ npm service not running"
fi

# Stop Docker service
if systemctl is-active --quiet docker 2>/dev/null; then
    systemctl stop docker 2>/dev/null || true
    echo "  ✓ Stopped docker service"
else
    echo "  ℹ docker service not running"
fi

# Stop CloudWatch Agent
if systemctl is-active --quiet amazon-cloudwatch-agent 2>/dev/null; then
    systemctl stop amazon-cloudwatch-agent 2>/dev/null || true
    echo "  ✓ Stopped amazon-cloudwatch-agent service"
else
    echo "  ℹ amazon-cloudwatch-agent service not running"
fi

echo "✓ Services stopped"

# Step 2: Clean apt caches
echo ""
echo "[2/7] Cleaning apt caches..."

apt-get clean
echo "  ✓ apt-get clean completed"

rm -rf /var/lib/apt/lists/*
echo "  ✓ Removed apt package lists"

echo "✓ Apt caches cleaned"

# Step 3: Clear log files
echo ""
echo "[3/7] Clearing log files..."

# List of log files to truncate
LOG_FILES=(
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/log/kern.log"
    "/var/log/dpkg.log"
    "/var/log/faillog"
    "/var/log/lastlog"
)

for log_file in "${LOG_FILES[@]}"; do
    if [[ -f "$log_file" ]]; then
        : > "$log_file"
        echo "  ✓ Truncated: $log_file"
    fi
done

# Remove rotated log files
if [[ -d /var/log ]]; then
    find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
    find /var/log -type f -name "*.[0-9]" -delete 2>/dev/null || true
    echo "  ✓ Removed rotated log files"
fi

# Clear journal logs
if command -v journalctl &> /dev/null; then
    journalctl --rotate
    journalctl --vacuum-time=1s
    echo "  ✓ Cleared systemd journal logs"
fi

echo "✓ Log files cleared"

# Step 4: Remove cloud-init instance data
echo ""
echo "[4/7] Removing cloud-init instance data..."

# Remove cloud-init logs and cache
if [[ -d /var/lib/cloud ]]; then
    rm -rf /var/lib/cloud/instances/*
    echo "  ✓ Removed cloud-init instance data"
fi

if [[ -f /var/log/cloud-init.log ]]; then
    : > /var/log/cloud-init.log 2>/dev/null || true
    echo "  ✓ Cleared cloud-init log"
fi

# Remove cloud-init semaphore files
rm -f /var/lib/cloud/sem/* 2>/dev/null || true

echo "✓ Cloud-init data removed"

# Step 5: Reset machine-id
echo ""
echo "[5/7] Resetting machine-id..."

if [[ -f /etc/machine-id ]]; then
    truncate -s 0 /etc/machine-id
    echo "  ✓ Truncated /etc/machine-id"
else
    touch /etc/machine-id
    echo "  ✓ Created empty /etc/machine-id"
fi

if [[ -f /var/lib/dbus/machine-id ]]; then
    truncate -s 0 /var/lib/dbus/machine-id
    echo "  ✓ Truncated /var/lib/dbus/machine-id"
fi

echo "✓ Machine-id reset"

# Step 6: Clear bash history
echo ""
echo "[6/7] Clearing bash history..."

# Clear root bash history
if [[ -f /root/.bash_history ]]; then
    : > /root/.bash_history
    echo "  ✓ Cleared root bash history"
fi

# Clear ubuntu user bash history if it exists
if [[ -f /home/ubuntu/.bash_history ]]; then
    : > /home/ubuntu/.bash_history
    echo "  ✓ Cleared ubuntu user bash history"
fi

# Clear other common history files
find /home -name ".bash_history" -type f -exec truncate -s 0 {} \; 2>/dev/null || true

echo "✓ Bash history cleared"

# Step 7: General cleanup
echo ""
echo "[7/7] Performing general cleanup..."

# Remove temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*
echo "  ✓ Cleared temporary directories"

# Remove package manager lock files (if any)
rm -f /var/lib/dpkg/lock* 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true
echo "  ✓ Removed package manager locks"

# Remove SSH known_hosts (if any)
find /root /home -name "known_hosts" -type f -delete 2>/dev/null || true
echo "  ✓ Removed SSH known_hosts files"

# Remove any AWS instance metadata cache (if exists)
rm -rf /var/lib/amazon/ssm/* 2>/dev/null || true

# Clear NPM logs directory (but keep the directory)
if [[ -d /var/log/npm ]]; then
    rm -f /var/log/npm/*.log 2>/dev/null || true
    echo "  ✓ Cleared NPM log files"
fi

# Remove any backup files created during setup
rm -f /opt/npm/*.bak 2>/dev/null || true

# Clear any swap files (if any were created)
swapoff -a 2>/dev/null || true
rm -f /swapfile 2>/dev/null || true
rm -f /swap.img 2>/dev/null || true

# Remove SSH host keys
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true
echo "  ✓ SSH host keys removed (will be regenerated on first boot)"

echo "✓ General cleanup completed"

# Sanity checks
echo ""
echo "Sanity checks:"
df -h /

if [[ -d /opt/npm ]]; then
    echo "  ✓ /opt/npm exists"
else
    echo "  ⚠ Warning: /opt/npm directory is missing"
fi

if [[ -f /usr/local/bin/npm-init.py ]]; then
    echo "  ✓ /usr/local/bin/npm-init.py present"
else
    echo "  ⚠ Warning: npm-init.py not found in /usr/local/bin"
fi

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ AMI cleanup completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary of cleanup actions:"
echo "  ✓ Services stopped (npm, docker, cloudwatch-agent)"
echo "  ✓ Apt caches and package lists removed"
echo "  ✓ Log files truncated and rotated logs removed"
echo "  ✓ Cloud-init instance data removed"
echo "  ✓ Machine-id reset"
echo "  ✓ Bash history cleared"
echo "  ✓ Temporary files and locks removed"
echo "  ✓ SSH host keys removed (regenerated on first boot)"
echo ""
echo "The instance is now ready for AMI creation."
echo ""
echo "Next steps:"
echo "  1. Verify the instance is in the desired state"
echo "  2. Create an AMI snapshot using AWS Console, CLI, or Packer"
echo "  3. Test the AMI by launching a new instance from it"
echo ""
echo "Note: Services will start automatically on first boot of instances"
echo "      launched from this AMI."
echo ""

exit 0

