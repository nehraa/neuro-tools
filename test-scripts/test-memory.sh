#!/bin/sh
# NeuroOS Memory Management & Compression Tests

echo "=========================================="
echo "  Memory Management & Compression Tests"
echo "=========================================="
echo ""

# Memory allocation test
echo "[1/5] Testing Memory Allocation..."
BEFORE=$(free | grep Mem | awk '{print $3}')
dd if=/dev/zero bs=1M count=100 > /tmp/mem-test.bin 2>/dev/null
AFTER=$(free | grep Mem | awk '{print $3}')
ALLOCATED=$((AFTER - BEFORE))
echo "  Allocated: $ALLOCATED MB"
rm /tmp/mem-test.bin

# Memory compression simulation
echo "[2/5] Testing Memory Compression..."
TEST_FILE="/tmp/compress-test.txt"
echo "NeuroOS Memory Compression Test" > "$TEST_FILE"
for i in $(seq 1 1000); do
    echo "This is a repetitive line that can be compressed." >> "$TEST_FILE"
done
ORIGINAL=$(stat -f%z "$TEST_FILE" 2>/dev/null || stat -c%s "$TEST_FILE")
gzip -c "$TEST_FILE" > "${TEST_FILE}.gz"
COMPRESSED=$(stat -f%z "${TEST_FILE}.gz" 2>/dev/null || stat -c%s "${TEST_FILE}.gz")
RATIO=$((COMPRESSED * 100 / ORIGINAL))
echo "  Original size: $ORIGINAL bytes"
echo "  Compressed size: $COMPRESSED bytes"
echo "  Compression ratio: $RATIO%"
rm "$TEST_FILE" "${TEST_FILE}.gz"

# Pointer arithmetic test
echo "[3/5] Testing Pointer Operations..."
cat > /tmp/pointer-test.sh << 'PTRTEST'
#!/bin/sh
# Simple pointer manipulation test
for i in 1 2 3 4 5; do
    PTR=$((0x$(printf '%08x' $((i * 4096)))))
    echo "Pointer $i: 0x$(printf '%08x' $PTR)"
done
PTRTEST
sh /tmp/pointer-test.sh
rm /tmp/pointer-test.sh

# Vector operations test
echo "[4/5] Testing Vector Data Structures..."
cat > /tmp/vector-test.sh << 'VECTEST'
#!/bin/sh
# Vector simulation with arrays
declare -a vector
for i in $(seq 0 9); do
    vector[$i]=$((i * 10))
done
echo "Vector elements:"
for i in $(seq 0 9); do
    echo "  vector[$i] = ${vector[$i]}"
done
VECTEST
bash /tmp/vector-test.sh 2>/dev/null || sh /tmp/vector-test.sh
rm /tmp/vector-test.sh

# Cache behavior test
echo "[5/5] Testing Cache & Memory Hierarchy..."
echo "Cache information (if available):"
cat /proc/cpuinfo | grep -i "cache" | head -5 || echo "  Cache info not available in this environment"

echo ""
echo "=========================================="
echo "✓ Memory Tests Complete"
echo "=========================================="
