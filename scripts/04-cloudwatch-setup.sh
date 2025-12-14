#!/usr/bin/env bash
# CloudWatch Agent Setup Script
# Installs and configures Amazon CloudWatch Agent on Ubuntu 22.04

set -euo pipefail

# Determine repo root and ami-files path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AMI_FILES="$REPO_ROOT/ami-files"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CloudWatch Agent Setup"
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

# Step 1: Determine config source and destination
echo "[1/5] Determining configuration paths..."

CONFIG_SOURCE="$AMI_FILES/opt-aws/amazon-cloudwatch-agent/amazon-cloudwatch-agent.json"
CONFIG_DEST_DIR="/opt/aws/amazon-cloudwatch-agent"
CONFIG_DEST="$CONFIG_DEST_DIR/amazon-cloudwatch-agent.json"

echo "  Config source: $CONFIG_SOURCE"
echo "  Config destination: $CONFIG_DEST"

# Ensure destination directory exists
mkdir -p "$CONFIG_DEST_DIR"
echo "  ✓ Destination directory created: $CONFIG_DEST_DIR"

# Step 2: Install Amazon CloudWatch Agent
echo ""
echo "[2/5] Installing Amazon CloudWatch Agent..."

INSTALL_METHOD=""

# Try installing via apt first
if apt-get update && apt-get install -y amazon-cloudwatch-agent 2>/dev/null; then
    INSTALL_METHOD="apt"
    echo "✓ CloudWatch Agent installed via apt package"
else
    echo "  apt package not available, downloading .deb from AWS..."
    
    # Download the official .deb for Ubuntu 22.04 (amd64)
    DEB_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
    DEB_FILE="/tmp/amazon-cloudwatch-agent.deb"
    
    if curl -fsSL "$DEB_URL" -o "$DEB_FILE"; then
        echo "  ✓ Downloaded CloudWatch Agent .deb"
        
        # Install the .deb package
        if dpkg -i "$DEB_FILE" 2>&1; then
            INSTALL_METHOD="deb"
            echo "✓ CloudWatch Agent installed via .deb package"
        else
            # Try to fix dependencies
            echo "  Fixing dependencies..."
            apt-get -f install -y
            INSTALL_METHOD="deb"
            echo "✓ CloudWatch Agent installed via .deb package (dependencies fixed)"
        fi
        
        # Clean up downloaded file
        rm -f "$DEB_FILE"
    else
        echo "✗ Error: Failed to download CloudWatch Agent .deb from $DEB_URL"
        exit 1
    fi
fi

if [[ -z "$INSTALL_METHOD" ]]; then
    echo "✗ Error: Failed to install CloudWatch Agent"
    exit 1
fi

# Step 3: Copy the config file and logrotate config
echo ""
echo "[3/5] Copying CloudWatch Agent configuration..."

if [[ ! -f "$CONFIG_SOURCE" ]]; then
    echo "✗ Error: CloudWatch Agent config not found at $CONFIG_SOURCE"
    exit 1
fi

# Validate JSON syntax (basic check)
if ! python3 -m json.tool "$CONFIG_SOURCE" > /dev/null 2>&1; then
    echo "⚠ Warning: Config file may not be valid JSON (continuing anyway)"
fi

cp "$CONFIG_SOURCE" "$CONFIG_DEST"
chown root:root "$CONFIG_DEST"
chmod 0644 "$CONFIG_DEST"
echo "✓ Configuration file copied to $CONFIG_DEST"

# Install Docker container log rotation config
LOGROTATE_SOURCE="$AMI_FILES/etc-logrotate.d/docker-containers"
LOGROTATE_DEST="/etc/logrotate.d/docker-containers"

if [[ -f "$LOGROTATE_SOURCE" ]]; then
    cp "$LOGROTATE_SOURCE" "$LOGROTATE_DEST"
    chown root:root "$LOGROTATE_DEST"
    chmod 0644 "$LOGROTATE_DEST"
    echo "✓ Docker logrotate config installed to $LOGROTATE_DEST"
else
    echo "⚠ Warning: Docker logrotate config not found at $LOGROTATE_SOURCE"
fi

# Step 4: Enable and configure the agent for runtime start
echo ""
echo "[4/5] Enabling CloudWatch Agent service..."

# Enable the service (will start on boot when IAM permissions are available)
if systemctl enable amazon-cloudwatch-agent --quiet 2>/dev/null; then
    echo "  ✓ Service enabled (will start on boot)"
else
    echo "  ⚠ Warning: Failed to enable service (may already be enabled)"
fi

# Attempt to start the service, but do not fail the build if CloudWatch access is unavailable
# This is expected during AMI build when no IAM role may be attached
echo "  Attempting to start service (may fail without IAM role)..."
if systemctl start amazon-cloudwatch-agent 2>/dev/null; then
    # Give it a moment to initialize
    sleep 2
    
    # Check if service is active
    if systemctl is-active --quiet amazon-cloudwatch-agent; then
        echo "  ✓ Service is active"
        SERVICE_STATUS="active"
    else
        echo "  ⚠ Service started but may not be fully active (expected without CloudWatch access)"
        SERVICE_STATUS="pending"
    fi
else
    echo "  ⚠ Service did not start (expected during AMI build without IAM role)"
    echo "    Service will start automatically on boot when IAM role is attached"
    SERVICE_STATUS="pending"
fi

# Step 5: Basic verification
echo ""
echo "[5/5] Verifying CloudWatch Agent installation..."

# Check if the control binary exists
CTL_BINARY="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

if [[ -f "$CTL_BINARY" ]]; then
    echo "  Running agent status check..."
    if "$CTL_BINARY" -a status 2>&1; then
        echo "  ✓ Agent status check completed"
    else
        echo "  ⚠ Warning: Agent status check returned non-zero (this may be normal)"
    fi
else
    echo "  ⚠ Warning: Control binary not found at $CTL_BINARY"
    echo "            Skipping status check"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ CloudWatch Agent setup completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo ""
echo "Installation method: $INSTALL_METHOD"
echo "Configuration file: $CONFIG_DEST"
if [[ -n "${SERVICE_STATUS:-}" ]]; then
    echo "Service status: $SERVICE_STATUS"
else
    echo "Service status: unknown"
fi
echo ""
echo "CloudWatch Agent will collect logs from:"
echo "  - /var/log/syslog"
echo "  - /var/log/auth.log"
echo "  - /var/lib/docker/containers/*/*-json.log"
echo ""
echo "Log group: /Northstar/npm"
echo "Log streams: {instance_id}-syslog, {instance_id}-auth, {instance_id}-docker"
echo ""
echo "Metrics collected (namespace: Northstar/System):"
echo "  - CPU: idle, iowait"
echo "  - Memory: used_percent"
echo "  - Disk: used_percent (/)"
echo "  - Network: bytes_sent, bytes_recv (eth0)"
echo ""
echo "Docker log rotation: /etc/logrotate.d/docker-containers"
echo "  - Daily rotation, 7 days retention, compressed"
echo ""
echo "Note: Ensure the instance has an IAM role with CloudWatch Logs permissions"
echo "      for logs to be successfully sent to CloudWatch."
echo ""
echo "Next steps:"
echo "  - Run 05-cleanup-for-ami.sh to prepare the instance for AMI creation"
echo ""

exit 0

