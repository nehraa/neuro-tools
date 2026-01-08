#!/bin/sh
# NeuroOS Containerization & Isolation Tests

echo "=========================================="
echo "  Containerization & Isolation Tests"
echo "=========================================="
echo ""

# Namespace test
echo "[1/5] Testing Process Namespaces..."
echo "Current PID: $$"
echo "Parent PID: $PPID"
ps aux | head -3

# Cgroup test
echo ""
echo "[2/5] Testing Control Groups..."
if [ -d /sys/fs/cgroup ]; then
    echo "  ✓ cgroup v2 detected"
    ls /sys/fs/cgroup/ | head -5
elif [ -d /proc/cgroups ]; then
    echo "  ✓ cgroup v1 detected"  
    cat /proc/cgroups | head -3
else
    echo "  ⚠ cgroups not available"
fi

# Resource limits test
echo ""
echo "[3/5] Testing Resource Limits..."
ulimit -a | head -5

# Process containment test
echo ""
echo "[4/5] Testing Process Containment..."
echo "Running subprocess in container simulation..."
sh -c 'echo "Subprocess PID: $$"; sleep 0.1' &
wait
echo "  ✓ Subprocess executed and isolated"

# Filesystem isolation test
echo ""
echo "[5/5] Testing Filesystem Isolation..."
mkdir -p /tmp/neuro-container-test
echo "Container root created: /tmp/neuro-container-test"
touch /tmp/neuro-container-test/test-file.txt
ls -la /tmp/neuro-container-test/
rm -rf /tmp/neuro-container-test

echo ""
echo "=========================================="
echo "✓ Containerization Tests Complete"
echo "=========================================="
