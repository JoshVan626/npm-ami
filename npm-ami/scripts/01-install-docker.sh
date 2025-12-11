#!/usr/bin/env bash
# Docker Installation Script
# Installs Docker Engine and Docker Compose plugin on Ubuntu 22.04

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Docker Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check prerequisites
echo "[1/5] Checking prerequisites..."

PREREQUISITES=("ca-certificates" "gnupg" "lsb-release")
MISSING_PKGS=()

for pkg in "${PREREQUISITES[@]}"; do
    if ! dpkg -l | grep -q "^ii.*$pkg "; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo "  Installing missing prerequisites: ${MISSING_PKGS[*]}"
    apt-get update
    apt-get install -y "${MISSING_PKGS[@]}"
else
    echo "✓ All prerequisites are installed"
fi

# Step 2: Add Docker's official GPG key and repository
echo ""
echo "[2/5] Adding Docker's official GPG key and repository..."

# Create keyrings directory if it doesn't exist
mkdir -p /etc/apt/keyrings

# Download and install Docker's GPG key
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set appropriate permissions
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "✓ Docker GPG key installed"
else
    echo "✓ Docker GPG key already exists"
fi

# Add Docker repository
DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

if [[ ! -f /etc/apt/sources.list.d/docker.list ]] || \
   ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
    echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo "✓ Docker repository added"
else
    echo "✓ Docker repository already configured"
fi

# Update package lists
echo "  Updating package lists..."
apt-get update

# Step 3: Install Docker packages
echo ""
echo "[3/5] Installing Docker packages..."

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

echo "✓ Docker packages installed successfully"

# Step 4: Enable and start Docker service
echo ""
echo "[4/5] Enabling and starting Docker service..."

systemctl enable docker
systemctl start docker

# Verify Docker service is active
if systemctl is-active --quiet docker; then
    echo "✓ Docker service is active"
else
    echo "✗ Error: Docker service is not active"
    exit 1
fi

# Step 5: Add ubuntu user to docker group
echo ""
echo "[5/5] Adding ubuntu user to docker group..."

if id -u ubuntu &>/dev/null; then
    usermod -aG docker ubuntu
    echo "✓ ubuntu user added to docker group"
    echo "  Note: User must log out and back in for group changes to take effect"
    UBUNTU_ADDED=true
else
    echo "⚠ Warning: ubuntu user not found; skipping docker group assignment"
    UBUNTU_ADDED=false
fi

# Step 6: Verification
echo ""
echo "Verifying Docker installation..."

DOCKER_VERSION=$(docker --version)
DOCKER_COMPOSE_VERSION=$(docker compose version)

if [[ -z "$DOCKER_VERSION" ]]; then
    echo "✗ Error: docker --version failed"
    exit 1
fi

if [[ -z "$DOCKER_COMPOSE_VERSION" ]]; then
    echo "✗ Error: docker compose version failed"
    exit 1
fi

echo "✓ $DOCKER_VERSION"
echo "✓ $DOCKER_COMPOSE_VERSION"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Docker installation completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  - Docker Engine installed: $DOCKER_VERSION"
echo "  - Docker Compose plugin installed: $DOCKER_COMPOSE_VERSION"
echo "  - Docker service enabled and started"
if [[ "$UBUNTU_ADDED" == true ]]; then
    echo "  - ubuntu user added to docker group"
else
    echo "  - ubuntu user not found (skipped docker group assignment)"
fi
echo ""
echo "Next steps:"
echo "  - Run 02-setup-npm-stack.sh to set up the NPM stack"
echo ""

exit 0

