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
BASH_SCRIPTS=("npm-backup" "npm-restore" "npm-diagnostics" "npm-support-bundle" "npm-preflight" "npm-postinit" "npm-update-container" "npm-stack-start" "npm-cert-check" "northstar")

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

if [[ -f "$AMI_FILES/etc/npm-cert-check.conf" ]]; then
    cp "$AMI_FILES/etc/npm-cert-check.conf" "/etc/npm-cert-check.conf"
    chown root:root "/etc/npm-cert-check.conf"
    chmod 0644 "/etc/npm-cert-check.conf"
    echo "✓ Copied npm-cert-check.conf to /etc/"
fi

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
    "npm-cert-check.service"
    "npm-cert-check.timer"
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

if systemctl enable npm-cert-check.timer --quiet; then
    ENABLED_UNITS+=("npm-cert-check.timer")
    echo "  ✓ Enabled: npm-cert-check.timer"
else
    echo "  ✗ Error: Failed to enable npm-cert-check.timer"
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

# Step 7: Write build manifest for support and reproducibility
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Writing build manifest..."

BUILD_MANIFEST_DIR="/opt/northstar"
BUILD_MANIFEST_PATH="$BUILD_MANIFEST_DIR/build-manifest.txt"

mkdir -p "$BUILD_MANIFEST_DIR"

BUILD_TIMESTAMP_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ" || echo "N/A")"
KERNEL_VERSION="$(uname -r || echo "N/A")"

DOCKER_VERSION_VALUE="N/A"
if command -v docker >/dev/null 2>&1; then
    # Capture docker version without failing the build if the command errors.
    if docker --version >/dev/null 2>&1; then
        DOCKER_VERSION_VALUE="$(docker --version 2>/dev/null || echo "docker --version (error)")"
    fi
fi

OS_RELEASE_CONTENT="N/A"
if [[ -f /etc/os-release ]]; then
    OS_RELEASE_CONTENT="$(cat /etc/os-release 2>/dev/null || echo "N/A")"
elif command -v lsb_release >/dev/null 2>&1; then
    OS_RELEASE_CONTENT="$(lsb_release -a 2>/dev/null || echo "N/A")"
fi

NPM_IMAGE_TAGS_VALUE="N/A"
if [[ -f /opt/npm/docker-compose.yml ]]; then
    # Best-effort extraction of image tags from docker-compose.yml.
    if NPM_IMAGE_TAGS_PARSED="$(grep -E '^[[:space:]]*image:[[:space:]]+' /opt/npm/docker-compose.yml 2>/dev/null | awk '{print $2}' | paste -sd ', ' - 2>/dev/null)"; then
        if [[ -n "${NPM_IMAGE_TAGS_PARSED:-}" ]]; then
            NPM_IMAGE_TAGS_VALUE="$NPM_IMAGE_TAGS_PARSED"
        fi
    fi
fi

DPKG_SNAPSHOT_TEMP=""
DPKG_SNAPSHOT_OK=0
if command -v dpkg-query >/dev/null 2>&1; then
    DPKG_SNAPSHOT_TEMP="$(mktemp /tmp/npm-dpkg-snapshot.XXXXXX || echo "")"
    if [[ -n "$DPKG_SNAPSHOT_TEMP" ]]; then
        if dpkg-query -W -f='${Package} ${Version}\n' >"$DPKG_SNAPSHOT_TEMP" 2>/dev/null; then
            DPKG_SNAPSHOT_OK=1
        fi
    fi
fi

{
    echo "Nginx Proxy Manager (NPM) for AWS — Build Manifest"
    echo "Timestamp (UTC): $BUILD_TIMESTAMP_UTC"
    echo ""
    echo "== OS Release =="
    echo "$OS_RELEASE_CONTENT"
    echo ""
    echo "== Kernel Version =="
    echo "$KERNEL_VERSION"
    echo ""
    echo "== Docker Version =="
    echo "$DOCKER_VERSION_VALUE"
    echo ""
    echo "== NPM Container Image Tags (best-effort) =="
    echo "$NPM_IMAGE_TAGS_VALUE"
    echo ""
    echo "== dpkg Package Snapshot =="
    if [[ "$DPKG_SNAPSHOT_OK" -eq 1 && -n "$DPKG_SNAPSHOT_TEMP" ]]; then
        cat "$DPKG_SNAPSHOT_TEMP"
    else
        echo "N/A (dpkg-query snapshot unavailable)"
    fi
} >"$BUILD_MANIFEST_PATH" 2>/dev/null || echo "⚠ Warning: Failed to write build manifest to $BUILD_MANIFEST_PATH"

if [[ -f "$BUILD_MANIFEST_PATH" ]]; then
    chown root:root "$BUILD_MANIFEST_PATH" 2>/dev/null || true
    chmod 0644 "$BUILD_MANIFEST_PATH" 2>/dev/null || true
    echo "✓ Build manifest written to $BUILD_MANIFEST_PATH"
else
    echo "⚠ Warning: Build manifest file not found at $BUILD_MANIFEST_PATH (non-fatal)"
fi

if [[ "$DPKG_SNAPSHOT_OK" -eq 1 && -n "$DPKG_SNAPSHOT_TEMP" ]]; then
    rm -f "$DPKG_SNAPSHOT_TEMP" 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Build manifest step completed (best-effort)."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
