#!/bin/sh
# NeuroOS Master Test Orchestrator
# One-click comprehensive testing and benchmarking

VERSION="0.1.0"
TEST_SUITE_DIR="/opt/neuro/tests"
RESULTS_DIR="/tmp/neuro-results"
LOG_FILE="$RESULTS_DIR/master-test-log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════╗
║     NeuroOS Comprehensive Test Suite v0.1.0         ║
║                                                      ║
║  Testing all NeuroOS features:                       ║
║  • Memory Management & Compression                   ║
║  • Containerization & Isolation                      ║
║  • Capabilities & Security                           ║
║  • Vector Operations & Data Structures               ║
║  • Performance Benchmarks                            ║
║                                                      ║
║  Test Results: /tmp/neuro-results/                  ║
╚══════════════════════════════════════════════════════╝
EOF
}

show_menu() {
    echo ""
    echo "Select Test Suite:"
    echo "  [1] All Tests (Full Verification) - ~2 minutes"
    echo "  [2] Core Features Only - ~30 seconds"
    echo "  [3] Memory & Compression - ~45 seconds"
    echo "  [4] Containerization - ~30 seconds"
    echo "  [5] Security & Capabilities - ~20 seconds"
    echo "  [6] Performance Benchmarks - ~60 seconds"
    echo "  [7] Quick Smoke Test - ~10 seconds"
    echo "  [0] Exit"
    echo ""
    echo -n "Enter choice [0-7]: "
    read CHOICE
}

run_all_tests() {
    echo "Running ALL TESTS..." | tee -a "$LOG_FILE"
    echo "================================" >> "$LOG_FILE"
    
    echo ""
    echo "Phase 1: Core Functionality Tests"
    sh "$TEST_SUITE_DIR/test-all.sh" 2>&1 | tee -a "$LOG_FILE"
    
    echo ""
    echo "Phase 2: Memory Management Tests"
    sh "$TEST_SUITE_DIR/test-memory.sh" 2>&1 | tee -a "$LOG_FILE"
    
    echo ""
    echo "Phase 3: Containerization Tests"
    sh "$TEST_SUITE_DIR/test-containers.sh" 2>&1 | tee -a "$LOG_FILE"
    
    echo ""
    echo "Phase 4: Security & Capabilities Tests"
    sh "$TEST_SUITE_DIR/test-capabilities.sh" 2>&1 | tee -a "$LOG_FILE"
    
    echo ""
    echo "Phase 5: Performance Benchmarks"
    sh "$TEST_SUITE_DIR/benchmark.sh" 2>&1 | tee -a "$LOG_FILE"
}

run_quick_test() {
    echo "Running QUICK SMOKE TEST..." | tee -a "$LOG_FILE"
    echo "Testing basic functionality..."
    
    TESTS=0
    PASSED=0
    
    # Quick tests
    for test in "ls /" "pwd" "echo test" "date" "whoami"; do
        TESTS=$((TESTS + 1))
        if eval "$test" > /dev/null 2>&1; then
            PASSED=$((PASSED + 1))
            echo "  ✓ $test"
        else
            echo "  ✗ $test"
        fi
    done
    
    echo ""
    echo "Quick Test Result: $PASSED/$TESTS passed"
}

show_results() {
    echo ""
    echo "Test Results Summary:"
    echo "====================="
    
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Recent test output:"
        tail -20 "$LOG_FILE"
        echo ""
        echo "Full log available at: $LOG_FILE"
    fi
    
    echo ""
    echo "Results directory: $RESULTS_DIR"
    ls -lh "$RESULTS_DIR"
}

# Main execution
banner

echo ""
echo "System Information:"
echo "  OS: $(uname -s)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  CPUs: $(nproc 2>/dev/null || echo 'N/A')"
echo "  Memory: $(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo 'N/A')"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
echo ""

echo "Test Suite Location: $TEST_SUITE_DIR"
echo "Test Log: $LOG_FILE"
echo ""

# Check if test scripts exist
if [ ! -d "$TEST_SUITE_DIR" ]; then
    echo "⚠ Warning: Test suite directory not found at $TEST_SUITE_DIR"
    echo "Creating test directory..."
    mkdir -p "$TEST_SUITE_DIR"
fi

# Main loop
while true; do
    show_menu
    
    case "$CHOICE" in
        1)
            echo "Starting complete test suite..."
            run_all_tests
            show_results
            ;;
        2)
            echo "Running core features test..."
            sh "$TEST_SUITE_DIR/test-all.sh" 2>&1 | tee -a "$LOG_FILE"
            ;;
        3)
            echo "Running memory tests..."
            sh "$TEST_SUITE_DIR/test-memory.sh" 2>&1 | tee -a "$LOG_FILE"
            ;;
        4)
            echo "Running containerization tests..."
            sh "$TEST_SUITE_DIR/test-containers.sh" 2>&1 | tee -a "$LOG_FILE"
            ;;
        5)
            echo "Running security tests..."
            sh "$TEST_SUITE_DIR/test-capabilities.sh" 2>&1 | tee -a "$LOG_FILE"
            ;;
        6)
            echo "Running benchmarks..."
            sh "$TEST_SUITE_DIR/benchmark.sh" 2>&1 | tee -a "$LOG_FILE"
            ;;
        7)
            echo "Running quick smoke test..."
            run_quick_test
            ;;
        0)
            echo ""
            echo "Test suite completed!"
            echo "Results saved to: $RESULTS_DIR"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
