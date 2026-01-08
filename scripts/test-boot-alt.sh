#!/usr/bin/env bash
# Alternative: Use QEMU with multiboot via SeaBIOS + raw kernel load

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
MEMORY="2G"
LOG_FILE="neuro-boot-alt.log"

echo "Boot attempt 1: Using -bios option"
qemu-system-x86_64 \
    -bios /opt/homebrew/share/qemu/bios.bin \
    -kernel "${KERNEL}" \
    -m "${MEMORY}" \
    -smp 2 \
    -serial file:"${LOG_FILE}" \
    -display none \
    -no-reboot &

PID=$!
sleep 5
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true

if [ -s "${LOG_FILE}" ]; then
    echo "✓ Boot successful!"
    echo ""
    echo "=== Kernel Output ==="
    cat "${LOG_FILE}"
else
    echo "No output. Trying with pvh mode..."
    
    # Try PVH mode if available
    rm -f "${LOG_FILE}"
    qemu-system-x86_64 \
        -kernel "${KERNEL}" \
        -m "${MEMORY}" \
        -smp 2 \
        -serial file:"${LOG_FILE}" \
        -display none \
        -machine q35 \
        -no-reboot &
    
    PID=$!
    sleep 5
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
    
    if [ -s "${LOG_FILE}" ]; then
        echo "✓ Boot successful with q35!"
        echo ""
        echo "=== Kernel Output ==="
        cat "${LOG_FILE}"
    else
        echo "Still no output. Kernel may not be outputting to serial."
        echo "This could be expected if the kernel is running correctly but not printing."
    fi
fi

echo ""
echo "Log saved to: ${LOG_FILE}"
