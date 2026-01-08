#!/usr/bin/env bash
# Test NeuroOS ISO in QEMU and capture output

ISO_FILE="NeuroOS-x86_64.iso"
LOG_FILE="neuro-iso-boot.log"
MEMORY="2G"
CPUS="2"

echo "========================================"
echo "  NeuroOS ISO Boot Test (M1 → x86_64)"
echo "========================================"
echo ""
echo "ISO: ${ISO_FILE}"
echo "Memory: ${MEMORY}"
echo "CPUs: ${CPUS}"
echo ""
echo "Booting... (will run for 15 seconds)"
echo ""

# Boot ISO and capture serial output
qemu-system-x86_64 \
    -cdrom "${ISO_FILE}" \
    -m "${MEMORY}" \
    -smp "${CPUS}" \
    -serial file:"${LOG_FILE}" \
    -display none \
    -boot d &

PID=$!
echo "QEMU PID: ${PID}"
sleep 15

# Kill QEMU
kill ${PID} 2>/dev/null || true
wait ${PID} 2>/dev/null || true

echo ""
echo "========================================"
echo "  Boot Test Complete"
echo "========================================"
echo ""

if [ -f "${LOG_FILE}" ] && [ -s "${LOG_FILE}" ]; then
    SIZE=$(wc -c < "${LOG_FILE}")
    LINES=$(wc -l < "${LOG_FILE}")
    echo "Serial output: ${SIZE} bytes, ${LINES} lines"
    echo ""
    echo "=== Boot Log (first 50 lines) ==="
    head -50 "${LOG_FILE}"
    echo ""
    if [ ${LINES} -gt 50 ]; then
        echo "... (${LINES} total lines, truncated)"
        echo ""
        echo "Full log saved to: ${LOG_FILE}"
    fi
else
    echo "No serial output captured."
    echo "ISO may have booted to GUI or kernel didn't output to serial."
fi

echo ""
echo "To boot interactively:"
echo "  qemu-system-x86_64 -cdrom ${ISO_FILE} -m 2G"
