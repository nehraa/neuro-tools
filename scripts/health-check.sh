#!/bin/bash
# Health Check Script for Neuro-OS Services
#
# Monitor the health of all Neuro-OS services and report status.
#
# Usage:
#   ./health-check.sh [--target HOST] [--watch]

set -euo pipefail

TARGET_HOST="${TARGET_HOST:-localhost}"
WATCH_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target) TARGET_HOST="$2"; shift 2 ;;
        --watch) WATCH_MODE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Check service health
check_health() {
    echo "========================================"
    echo "  Neuro-OS Health Check"
    echo "  Target: $TARGET_HOST"
    echo "  Time: $(date)"
    echo "========================================"
    echo
    
    # System uptime
    echo "[SYSTEM] Uptime:"
    ssh "$TARGET_HOST" "uptime" || echo "  ✗ Unable to connect"
    echo
    
    # Memory usage
    echo "[MEMORY] Usage:"
    ssh "$TARGET_HOST" "free -h" || echo "  ✗ Unable to get memory info"
    echo
    
    # Disk usage
    echo "[DISK] Usage:"
    ssh "$TARGET_HOST" "df -h /" || echo "  ✗ Unable to get disk info"
    echo
    
    # Service status
    echo "[SERVICES] Status:"
    ssh "$TARGET_HOST" "systemctl list-units 'neuro-*' --no-pager" || echo "  ✗ Unable to get service status"
    echo
    
    # Process count
    echo "[PROCESSES] Count:"
    ssh "$TARGET_HOST" "ps aux | grep neuro | grep -v grep | wc -l" || echo "  ✗ Unable to count processes"
    echo
    
    echo "========================================"
}

# Main execution
if [[ "$WATCH_MODE" == "true" ]]; then
    while true; do
        clear
        check_health
        echo "Refreshing in 5 seconds... (Ctrl+C to stop)"
        sleep 5
    done
else
    check_health
fi
