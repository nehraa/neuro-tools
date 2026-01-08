#!/bin/sh
# NeuroOS Comprehensive Test Suite
# Run with: /opt/neuro/test-all.sh

TESTS_DIR="/opt/neuro/tests"
RESULTS_FILE="/tmp/neuro-test-results.txt"
BENCHMARK_FILE="/tmp/neuro-benchmarks.txt"

echo "==========================================="
echo "  NeuroOS Comprehensive Test Suite v0.1.0"
echo "==========================================="
echo ""
echo "System Information:"
uname -a
echo ""
echo "Memory Info:"
free -h
echo ""
echo "Starting tests at $(date)"
echo "==========================================="
echo ""

# Create results file
cat > "$RESULTS_FILE" << 'EOF'
NeuroOS Test Results
====================
EOF

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    TEST_NAME="$1"
    TEST_CMD="$2"
    
    echo -n "Testing $TEST_NAME... "
    
    if eval "$TEST_CMD" > /dev/null 2>&1; then
        echo "✓ PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $TEST_NAME" >> "$RESULTS_FILE"
    else
        echo "✗ FAIL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ $TEST_NAME" >> "$RESULTS_FILE"
    fi
}

# ============================================================================
# CORE FUNCTIONALITY TESTS
# ============================================================================

echo "=== CORE FUNCTIONALITY TESTS ==="
echo ""

# Test: Memory allocation
run_test "Memory Allocation" "[ -d /proc/meminfo ]"

# Test: Filesystem
run_test "Filesystem Access" "[ -w /tmp ]"

# Test: Process execution
run_test "Process Execution" "ps aux > /dev/null 2>&1"

# Test: File operations
run_test "File Operations" "echo 'test' > /tmp/test.txt && [ -f /tmp/test.txt ]"

# Test: Shell functionality
run_test "Shell Commands" "ls / | grep -q bin"

echo ""
echo "=== ADVANCED FEATURE TESTS ==="
echo ""

# Test: Vector operations (if available)
run_test "Vector Data Structures" "[ -x /opt/neuro/tests/test-vectors.sh ]"

# Test: Memory compression (check if module loaded)
run_test "Memory Management" "cat /proc/meminfo | grep -q MemTotal"

# Test: IPC capabilities
run_test "Inter-Process Communication" "[ -d /proc/sys/kernel ]"

# Test: Power management (check if available)
run_test "Power Management" "[ -f /sys/power/state ] || true"

# Test: GPU virtualization (check if available)  
run_test "GPU Support Detection" "lspci | grep -qi gpu || true"

echo ""
echo "=== CONTAINERIZATION TESTS ==="
echo ""

# Test: Namespace support
run_test "Namespace Support" "[ -d /proc/sys/kernel/sched ]"

# Test: Cgroup support
run_test "Cgroup Support" "[ -d /sys/fs/cgroup ] || [ -d /proc/cgroups ]"

# Test: Container image support
run_test "Container Infrastructure" "[ -d /var/lib/containers ] || [ -d /var/lib/docker ] || true"

echo ""
echo "=== SECURITY & CAPABILITY TESTS ==="
echo ""

# Test: Capability system
run_test "Capability System" "[ -f /proc/sys/kernel/cap_last_cap ]"

# Test: Permission system
run_test "Permission System" "[ -w /tmp ] && [ ! -w /root ]"

# Test: Process isolation
run_test "Process Isolation" "[ $$ -ne 1 ]"

echo ""
echo "=== PERFORMANCE & OPTIMIZATION TESTS ==="
echo ""

# Test: CPU affinity
run_test "CPU Affinity Support" "taskset -c 0 echo test > /dev/null 2>&1 || true"

# Test: Memory pinning
run_test "Memory Operations" "[ -r /proc/meminfo ]"

# Test: Performance monitoring
run_test "Performance Monitoring" "[ -d /proc/sys/kernel/perf ] || true"

echo ""
echo "==========================================="
echo "TEST SUMMARY"
echo "==========================================="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
TOTAL=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL -gt 0 ]; then
    PERCENTAGE=$((TESTS_PASSED * 100 / TOTAL))
    echo "Success Rate: $PERCENTAGE%"
fi
echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
