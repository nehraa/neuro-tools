#!/bin/sh
# NeuroOS Performance & Benchmark Suite

echo "=========================================="
echo "  NeuroOS Performance Benchmarks"
echo "=========================================="
echo ""
echo "Start time: $(date)"
echo ""

BENCHMARK_FILE="/tmp/neuro-benchmarks.txt"
cat > "$BENCHMARK_FILE" << 'EOF'
NeuroOS Performance Benchmarks
==============================
EOF

# CPU Performance Benchmark
echo "[1/6] CPU Performance Benchmark..."
echo "  Running CPU intensive operations..."
START=$(date +%s%N)

# Simple CPU test - counting to 1 million
COUNT=0
while [ $COUNT -lt 1000000 ]; do
    COUNT=$((COUNT + 1))
done

END=$(date +%s%N)
CPU_TIME=$((($END - $START) / 1000000))
echo "  CPU operations (1M iterations): ${CPU_TIME}ms" | tee -a "$BENCHMARK_FILE"

# Memory Bandwidth Benchmark
echo ""
echo "[2/6] Memory Bandwidth Benchmark..."
echo "  Allocating 100MB and measuring throughput..."
dd if=/dev/zero of=/tmp/bench.bin bs=1M count=100 2>/dev/null
READ_RATE=$(dd if=/tmp/bench.bin of=/dev/null bs=1M 2>&1 | grep bytes | awk '{print $6 " " $7}')
echo "  Memory read rate: $READ_RATE" | tee -a "$BENCHMARK_FILE"
rm /tmp/bench.bin

# Filesystem Performance
echo ""
echo "[3/6] Filesystem Performance Benchmark..."
echo "  Writing 10000 files..."
START=$(date +%s%N)

for i in $(seq 1 10000); do
    echo "test$i" > /tmp/file-$i.txt 2>/dev/null
done

END=$(date +%s%N)
FS_TIME=$((($END - $START) / 1000000))
echo "  File write test (10K files): ${FS_TIME}ms" | tee -a "$BENCHMARK_FILE"

# Clean up
for i in $(seq 1 10000); do
    rm -f /tmp/file-$i.txt
done

# Process Creation Benchmark
echo ""
echo "[4/6] Process Creation Benchmark..."
echo "  Spawning 100 processes..."
START=$(date +%s%N)

for i in $(seq 1 100); do
    (true) &
done
wait

END=$(date +%s%N)
PROC_TIME=$((($END - $START) / 1000000))
echo "  Process spawn test (100 procs): ${PROC_TIME}ms" | tee -a "$BENCHMARK_FILE"

# Context Switch Benchmark
echo ""
echo "[5/6] Context Switch Benchmark..."
echo "  Creating concurrent background jobs..."
START=$(date +%s%N)

for i in $(seq 1 10); do
    (for j in $(seq 1 1000); do true; done) &
done
wait

END=$(date +%s%N)
SWITCH_TIME=$((($END - $START) / 1000000))
echo "  Context switches (10 jobs): ${SWITCH_TIME}ms" | tee -a "$BENCHMARK_FILE"

# System Call Benchmark
echo ""
echo "[6/6] System Call Benchmark..."
echo "  Executing syscalls..."
START=$(date +%s%N)

for i in $(seq 1 1000); do
    sh -c 'echo $$' > /dev/null
done

END=$(date +%s%N)
SYSCALL_TIME=$((($END - $START) / 1000000))
echo "  System call overhead (1K calls): ${SYSCALL_TIME}ms" | tee -a "$BENCHMARK_FILE"

# Summary
echo ""
echo "=========================================="
echo "BENCHMARK SUMMARY"
echo "=========================================="
echo ""
echo "CPU Performance:       ${CPU_TIME}ms"
echo "Memory Bandwidth:      $READ_RATE"
echo "Filesystem I/O:        ${FS_TIME}ms (10K files)"
echo "Process Creation:      ${PROC_TIME}ms (100 processes)"
echo "Context Switches:      ${SWITCH_TIME}ms (10 concurrent)"
echo "System Call Overhead:  ${SYSCALL_TIME}ms (1K calls)"
echo ""
echo "Full results saved to: $BENCHMARK_FILE"
cat "$BENCHMARK_FILE"
echo ""
echo "End time: $(date)"
echo "=========================================="
