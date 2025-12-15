#!/usr/bin/env bash
# NPM Stack Setup Script
# Copies NPM-related files to their final locations and configures systemd

set -euo pipefail

# Determine repo root and ami-files path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AMI_FILES="$REPO_ROOT/ami-files"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NPM Stack Setup"
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

# Step 1: Create required directories
echo "[1/6] Creating required directories..."

DIRECTORIES=(
    "/opt/npm"
    "/opt/npm/data"
    "/opt/npm/letsencrypt"
    "/var/log/npm"
)

for dir in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "  Created: $dir"
    else
        echo "  Exists: $dir"
    fi
done

echo "✓ Directories created"

# Step 2: Copy Docker Compose file
echo ""
echo "[2/6] Copying Docker Compose file..."

if [[ ! -f "$AMI_FILES/opt-npm/docker-compose.yml" ]]; then
    echo "✗ Error: docker-compose.yml not found at $AMI_FILES/opt-npm/docker-compose.yml"
    exit 1
fi

cp "$AMI_FILES/opt-npm/docker-compose.yml" "/opt/npm/docker-compose.yml"
chown root:root "/opt/npm/docker-compose.yml"
chmod 0644 "/opt/npm/docker-compose.yml"
echo "✓ Copied docker-compose.yml to /opt/npm/"

# Step 3: Install Python helper scripts and diagnostics
echo ""
echo "[3/6] Installing Python helper scripts and diagnostics..."

PYTHON_SCRIPTS=("npm-init.py" "npm-helper" "npm_common.py")
BASH_SCRIPTS=("npm-backup" "npm-restore" "npm-diagnostics" "npm-support-bundle" "npm-preflight" "npm-postinit" "npm-update-container")

# Copy Python scripts
for script in "${PYTHON_SCRIPTS[@]}"; do
    if [[ ! -f "$AMI_FILES/usr-local-bin/$script" ]]; then
        echo "✗ Error: $script not found at $AMI_FILES/usr-local-bin/$script"
        exit 1
    fi
    
    cp "$AMI_FILES/usr-local-bin/$script" "/usr/local/bin/$script"
    chown root:root "/usr/local/bin/$script"
    chmod 0755 "/usr/local/bin/$script"
    echo "  Copied: $script"
    
    # Sanity check: verify shebang exists
    if head -n 1 "/usr/local/bin/$script" | grep -q "^#!"; then
        echo "    ✓ Shebang verified"
    else
        echo "    ⚠ Warning: No shebang found in $script"
    fi
done

# Copy bash scripts (like npm-diagnostics)
for script in "${BASH_SCRIPTS[@]}"; do
    if [[ ! -f "$AMI_FILES/usr-local-bin/$script" ]]; then
        echo "✗ Error: $script not found at $AMI_FILES/usr-local-bin/$script"
        exit 1
    fi
    
    cp "$AMI_FILES/usr-local-bin/$script" "/usr/local/bin/$script"
    chown root:root "/usr/local/bin/$script"
    chmod 0755 "/usr/local/bin/$script"
    echo "  Copied: $script"
    
    # Sanity check: verify shebang exists
    if head -n 1 "/usr/local/bin/$script" | grep -q "^#!"; then
        echo "    ✓ Shebang verified"
    else
        echo "    ⚠ Warning: No shebang found in $script"
    fi
done

echo "✓ Scripts installed"

# Step 4: Install backup configuration
echo ""
echo "[4/6] Installing backup configuration..."

if [[ ! -f "$AMI_FILES/etc/npm-backup.conf" ]]; then
    echo "✗ Error: npm-backup.conf not found at $AMI_FILES/etc/npm-backup.conf"
    exit 1
fi

cp "$AMI_FILES/etc/npm-backup.conf" "/etc/npm-backup.conf"
chown root:root "/etc/npm-backup.conf"
chmod 0644 "/etc/npm-backup.conf"
echo "✓ Copied npm-backup.conf to /etc/"

# Step 5: Install systemd units
echo ""
echo "[5/6] Installing systemd units..."

SYSTEMD_UNITS=(
    "npm.service"
    "npm-init.service"
    "npm-preflight.service"
    "npm-postinit.service"
    "npm-backup.service"
    "npm-backup.timer"
)

for unit in "${SYSTEMD_UNITS[@]}"; do
    if [[ ! -f "$AMI_FILES/etc-systemd-system/$unit" ]]; then
        echo "✗ Error: $unit not found at $AMI_FILES/etc-systemd-system/$unit"
        exit 1
    fi
    
    cp "$AMI_FILES/etc-systemd-system/$unit" "/etc/systemd/system/$unit"
    chown root:root "/etc/systemd/system/$unit"
    chmod 0644 "/etc/systemd/system/$unit"
    echo "  Copied: $unit"
done

echo "✓ Systemd units installed"

# Step 6: systemd daemon reload and enable units
echo ""
echo "[6/6] Reloading systemd and enabling units..."

systemctl daemon-reload
echo "✓ systemd daemon reloaded"

# Enable services and timer
ENABLED_UNITS=()

if systemctl enable npm.service --quiet; then
    ENABLED_UNITS+=("npm.service")
    echo "  ✓ Enabled: npm.service"
else
    echo "  ✗ Error: Failed to enable npm.service"
    exit 1
fi

if systemctl enable npm-init.service --quiet; then
    ENABLED_UNITS+=("npm-init.service")
    echo "  ✓ Enabled: npm-init.service"
else
    echo "  ✗ Error: Failed to enable npm-init.service"
    exit 1
fi

if systemctl enable npm-preflight.service --quiet; then
    ENABLED_UNITS+=("npm-preflight.service")
    echo "  ✓ Enabled: npm-preflight.service"
else
    echo "  ✗ Error: Failed to enable npm-preflight.service"
    exit 1
fi

if systemctl enable npm-postinit.service --quiet; then
    ENABLED_UNITS+=("npm-postinit.service")
    echo "  ✓ Enabled: npm-postinit.service"
else
    echo "  ✗ Error: Failed to enable npm-postinit.service"
    exit 1
fi

if systemctl enable npm-backup.timer --quiet; then
    ENABLED_UNITS+=("npm-backup.timer")
    echo "  ✓ Enabled: npm-backup.timer"
else
    echo "  ✗ Error: Failed to enable npm-backup.timer"
    exit 1
fi

echo "✓ Systemd units enabled"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ NPM stack setup completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo ""
echo "Directories created:"
for dir in "${DIRECTORIES[@]}"; do
    echo "  - $dir"
done
echo ""
echo "Files copied:"
echo "  - /opt/npm/docker-compose.yml"
for script in "${PYTHON_SCRIPTS[@]}"; do
    echo "  - /usr/local/bin/$script"
done
for script in "${BASH_SCRIPTS[@]}"; do
    echo "  - /usr/local/bin/$script"
done
echo "  - /etc/npm-backup.conf"
for unit in "${SYSTEMD_UNITS[@]}"; do
    echo "  - /etc/systemd/system/$unit"
done
echo ""
echo "Systemd units enabled:"
for unit in "${ENABLED_UNITS[@]}"; do
    echo "  - $unit"
done
echo ""
echo "Note: Services will start automatically on boot."
echo "      npm.service and npm-init.service will run on first boot."
echo "      npm-backup.timer will run daily at 02:00."
echo ""
echo "Next steps:"
echo "  - Run 03-security-hardening.sh to configure security settings"
echo ""

exit 0


