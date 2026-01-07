#!/bin/bash
# Deploy Service Script for Neuro-OS
#
# Deploy a single service to the Neuro-OS system.
#
# Usage:
#   ./deploy-service.sh <service-name> [--target HOST] [--restart]

set -euo pipefail

SERVICE_NAME="${1:-}"
TARGET_HOST="${TARGET_HOST:-localhost}"
RESTART=false
SERVICE_DIR="/opt/neuro-services"

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --target) TARGET_HOST="$2"; shift 2 ;;
        --restart) RESTART=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SERVICE_NAME" ]]; then
    echo "Usage: $0 <service-name> [--target HOST] [--restart]"
    exit 1
fi

echo "Deploying service: $SERVICE_NAME to $TARGET_HOST"

# Build service
echo "[BUILD] Building service..."
cargo build --release --bin "$SERVICE_NAME"

# Stop existing service if requested
if [[ "$RESTART" == "true" ]]; then
    echo "[STOP] Stopping existing service..."
    ssh "$TARGET_HOST" "systemctl stop neuro-${SERVICE_NAME}" || true
fi

# Copy binary
echo "[DEPLOY] Copying binary..."
scp "target/release/${SERVICE_NAME}" "${TARGET_HOST}:${SERVICE_DIR}/"

# Install systemd service
echo "[INSTALL] Installing systemd service..."
cat > "/tmp/neuro-${SERVICE_NAME}.service" << EOF
[Unit]
Description=Neuro-OS ${SERVICE_NAME} Service
After=network.target

[Service]
Type=simple
ExecStart=${SERVICE_DIR}/${SERVICE_NAME}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

scp "/tmp/neuro-${SERVICE_NAME}.service" "${TARGET_HOST}:/etc/systemd/system/"
rm "/tmp/neuro-${SERVICE_NAME}.service"

# Reload and start service
echo "[START] Starting service..."
ssh "$TARGET_HOST" "systemctl daemon-reload && systemctl enable neuro-${SERVICE_NAME} && systemctl start neuro-${SERVICE_NAME}"

echo "✓ Service deployed successfully!"
echo "Check status: ssh $TARGET_HOST systemctl status neuro-${SERVICE_NAME}"
