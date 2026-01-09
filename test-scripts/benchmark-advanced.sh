#!/bin/sh
# Advanced NeuroOS Performance Benchmarks
# Precision measurements with multiple iterations

RESULTS="/tmp/neuro-advanced-benchmarks.txt"

echo "==========================================="
echo "  NeuroOS Advanced Performance Benchmarks"
echo "==========================================="
echo ""
echo "Test Start: $(date)"
echo ""

cat > "$RESULTS" << 'EOF'
NeuroOS Advanced Performance Benchmarks
=======================================

EOF

# 1. CPU Performance - Multiple iterations for accuracy
echo "[1/7] CPU Performance Benchmark..."
echo "Running CPU intensive test (10 iterations)..."

TOTAL_CPU=0
for iter in $(seq 1 10); do
    START=$(date +%s%N)
    COUNT=0
    while [ $COUNT -lt 100000 ]; do
        COUNT=$((COUNT + 1))
    done
    END=$(date +%s%N)
    CPU_TIME=$((($END - $START) / 1000000))
    TOTAL_CPU=$((TOTAL_CPU + CPU_TIME))
done

AVG_CPU=$((TOTAL_CPU / 10))
echo "✓ CPU (100K ops, avg): ${AVG_CPU}ms" | tee -a "$RESULTS"

# 2. Memory Performance - Sequential read/write
echo ""
echo "[2/7] Memory Performance Benchmark..."
START=$(date +%s%N)
# Create 50MB file
dd if=/dev/zero bs=1M count=50 of=/tmp/memtest.bin 2>/dev/null
END=$(date +%s%N)
WRITE_TIME=$((($END - $START) / 1000000))

START=$(date +%s%N)
dd if=/tmp/memtest.bin of=/dev/null bs=1M 2>/dev/null
END=$(date +%s%N)
READ_TIME=$((($END - $START) / 1000000))

echo "✓ Memory write (50MB): ${WRITE_TIME}ms" | tee -a "$RESULTS"
echo "✓ Memory read (50MB): ${READ_TIME}ms" | tee -a "$RESULTS"
rm /tmp/memtest.bin

# 3. Filesystem Performance - Small file I/O
echo ""
echo "[3/7] Filesystem Performance Benchmark..."
START=$(date +%s%N)

for i in $(seq 1 1000); do
    echo "test_data_$i" > /tmp/fstest-$i.txt 2>/dev/null
done

END=$(date +%s%N)
FS_WRITE=$((($END - $START) / 1000000))

START=$(date +%s%N)

for i in $(seq 1 1000); do
    cat /tmp/fstest-$i.txt > /dev/null 2>/dev/null
done

END=$(date +%s%N)
FS_READ=$((($END - $START) / 1000000))

echo "✓ Filesystem write (1K files): ${FS_WRITE}ms" | tee -a "$RESULTS"
echo "✓ Filesystem read (1K files): ${FS_READ}ms" | tee -a "$RESULTS"

# Cleanup
rm -f /tmp/fstest-*.txt

# 4. Process Performance
echo ""
echo "[4/7] Process Creation Benchmark..."
START=$(date +%s%N)

for i in $(seq 1 50); do
    (sleep 0.01) &
done
wait

END=$(date +%s%N)
PROC_TIME=$((($END - $START) / 1000000))
echo "✓ Process creation (50 procs): ${PROC_TIME}ms" | tee -a "$RESULTS"

# 5. Shell Command Execution
echo ""
echo "[5/7] Command Execution Benchmark..."
START=$(date +%s%N)

for i in $(seq 1 500); do
    sh -c 'true' > /dev/null
done

END=$(date +%s%N)
CMD_TIME=$((($END - $START) / 1000000))
echo "✓ Command execution (500 calls): ${CMD_TIME}ms" | tee -a "$RESULTS"

# 6. Pipe Performance
echo ""
echo "[6/7] Pipe Performance Benchmark..."
START=$(date +%s%N)

for i in $(seq 1 100000); do
    echo $i
done | wc -l > /dev/null

END=$(date +%s%N)
PIPE_TIME=$((($END - $START) / 1000000))
echo "✓ Pipe throughput (100K lines): ${PIPE_TIME}ms" | tee -a "$RESULTS"

# 7. System Information
echo ""
echo "[7/7] System Information..."
echo "" | tee -a "$RESULTS"
echo "=== SYSTEM STATUS ===" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

echo "CPU Info:" | tee -a "$RESULTS"
grep "processor" /proc/cpuinfo 2>/dev/null | wc -l | awk '{print "  CPUs: " $1}' | tee -a "$RESULTS"

echo "" | tee -a "$RESULTS"
echo "Memory Status:" | tee -a "$RESULTS"
free -h 2>/dev/null | tail -2 | sed 's/^/  /' | tee -a "$RESULTS"

echo "" | tee -a "$RESULTS"
echo "Disk Space:" | tee -a "$RESULTS"
df -h / 2>/dev/null | tail -1 | awk '{print "  Root: Used=" $3 " Free=" $4}' | tee -a "$RESULTS"

echo "" | tee -a "$RESULTS"
echo "=== SUMMARY ===" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"
echo "Average CPU Time (100K ops): ${AVG_CPU}ms" | tee -a "$RESULTS"
echo "Memory Write (50MB): ${WRITE_TIME}ms" | tee -a "$RESULTS"
echo "Memory Read (50MB): ${READ_TIME}ms" | tee -a "$RESULTS"
echo "Filesystem Write (1K files): ${FS_WRITE}ms" | tee -a "$RESULTS"
echo "Filesystem Read (1K files): ${FS_READ}ms" | tee -a "$RESULTS"
echo "Process Creation (50 procs): ${PROC_TIME}ms" | tee -a "$RESULTS"
echo "Command Execution (500 calls): ${CMD_TIME}ms" | tee -a "$RESULTS"
echo "Pipe Throughput (100K lines): ${PIPE_TIME}ms" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"
echo "End time: $(date)" | tee -a "$RESULTS"

echo ""
echo "==========================================="
echo "  Benchmarks Complete!"
echo "==========================================="
echo ""
echo "Results saved to: $RESULTS"
echo ""
cat "$RESULTS"
