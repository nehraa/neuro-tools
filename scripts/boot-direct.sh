#!/usr/bin/env bash
# NeuroOS Direct Boot - Uses QEMU's x86 firmware support

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
LOG_FILE="neuro-boot.log"

echo "NeuroOS Boot Test"
echo "================="
echo ""
echo "Attempting direct kernel boot on x86 with firmware..."
echo ""

# Try with SeaBIOS and memory write operations
qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -kernel "${KERNEL}" \
    -serial file:"${LOG_FILE}" \
    -display none \
    -machine q35,accel=tcg \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -no-reboot &

PID=$!
echo "QEMU PID: $PID"
sleep 6
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true

echo ""
echo "Boot attempt completed."
echo ""

if [ -f "${LOG_FILE}" ]; then
    SIZE=$(wc -c < "${LOG_FILE}")
    echo "Serial output size: ${SIZE} bytes"
    echo ""
    
    if [ $SIZE -gt 0 ]; then
        echo "=== Kernel Output ==="
        head -100 "${LOG_FILE}"
        echo ""
        echo "(output truncated if longer)"
    else
        echo "No serial output captured."
        echo "Note: Kernel may be running but not outputting to serial port."
        echo ""
        echo "Checking kernel binary info..."
        file "${KERNEL}"
        ls -lh "${KERNEL}"
    fi
else
    echo "Log file not created."
fi
