#!/bin/sh
# NeuroOS Capability & Security Tests

echo "=========================================="
echo "  Capability & Security Tests"
echo "=========================================="
echo ""

# Kernel capability test
echo "[1/4] Testing Kernel Capabilities..."
if [ -f /proc/sys/kernel/cap_last_cap ]; then
    LAST_CAP=$(cat /proc/sys/kernel/cap_last_cap)
    echo "  Total capabilities: $((LAST_CAP + 1))"
else
    echo "  ⚠ Capability system not directly available"
fi

# Current process capabilities
echo ""
echo "[2/4] Testing Process Capabilities..."
echo "Current user: $(whoami)"
echo "Current UID: $(id -u)"
echo "Current GID: $(id -g)"
echo "Groups: $(id -G)"

# Permission isolation test
echo ""
echo "[3/4] Testing Permission Isolation..."
echo "Testing file permissions:"
[ -w /tmp ] && echo "  ✓ /tmp is writable (as expected)"
[ -w /root ] && echo "  ⚠ /root is writable (unexpected)" || echo "  ✓ /root is protected"
[ -r /etc/passwd ] && echo "  ✓ /etc/passwd is readable"

# Security context test
echo ""
echo "[4/4] Testing Security Contexts..."
echo "Process information:"
cat /proc/self/status | grep -E "Uid|Gid|VmRSS|VmPeak"

echo ""
echo "=========================================="
echo "✓ Capability Tests Complete"
echo "=========================================="
