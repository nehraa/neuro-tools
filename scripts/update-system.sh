#!/bin/bash
# Update System Script for Neuro-OS
#
# Apply system updates including kernel, services, and configurations.
#
# Usage:
#   ./update-system.sh [--target HOST] [--reboot]

set -euo pipefail

TARGET_HOST="${TARGET_HOST:-localhost}"
REBOOT=false
UPDATE_DIR="/tmp/neuro-update"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target) TARGET_HOST="$2"; shift 2 ;;
        --reboot) REBOOT=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "Updating Neuro-OS on $TARGET_HOST"

# Create update package
echo "[PACKAGE] Creating update package..."
rm -rf "$UPDATE_DIR"
mkdir -p "$UPDATE_DIR"/{kernel,services,config}

# Build kernel
if [[ -d "neuro-kernel" ]]; then
    echo "[BUILD] Building kernel..."
    cd neuro-kernel
    cargo build --release
    cp target/release/neuro-kernel "$UPDATE_DIR/kernel/"
    cd ..
fi

# Build services
if [[ -d "neuro-services" ]]; then
    echo "[BUILD] Building services..."
    cd neuro-services
    cargo build --release
    cp target/release/* "$UPDATE_DIR/services/" 2>/dev/null || true
    cd ..
fi

# Package update
echo "[ARCHIVE] Creating update archive..."
tar czf /tmp/neuro-update.tar.gz -C "$UPDATE_DIR" .

# Transfer to target
echo "[TRANSFER] Transferring update..."
scp /tmp/neuro-update.tar.gz "${TARGET_HOST}:/tmp/"

# Apply update
echo "[APPLY] Applying update..."
ssh "$TARGET_HOST" << 'REMOTE_SCRIPT'
set -euo pipefail

# Extract update
cd /tmp
tar xzf neuro-update.tar.gz

# Backup current system
echo "Creating backup..."
mkdir -p /backup/$(date +%Y%m%d_%H%M%S)
cp /boot/neuro-kernel /backup/$(date +%Y%m%d_%H%M%S)/ || true

# Install kernel
if [[ -f kernel/neuro-kernel ]]; then
    echo "Installing kernel..."
    cp kernel/neuro-kernel /boot/
fi

# Install services
if [[ -d services ]]; then
    echo "Installing services..."
    cp services/* /opt/neuro-services/
    systemctl daemon-reload
fi

echo "Update applied successfully!"
REMOTE_SCRIPT

# Cleanup
rm -rf "$UPDATE_DIR" /tmp/neuro-update.tar.gz

if [[ "$REBOOT" == "true" ]]; then
    echo "[REBOOT] Rebooting system..."
    ssh "$TARGET_HOST" "reboot"
fi

echo "✓ System update completed!"
