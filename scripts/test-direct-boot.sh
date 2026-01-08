#!/usr/bin/env bash
# NeuroOS Simple Test - Direct QEMU boot (no GRUB)

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"

echo "Testing kernel with direct QEMU boot..."
echo ""

# Use multiboot directly with QEMU
qemu-system-x86_64 \
    -kernel "${KERNEL}" \
    -serial stdio \
    -m 2G \
    -display none \
    -no-reboot \
    -d guest_errors,cpu_reset 2>&1 &

PID=$!
echo "QEMU PID: $PID"
echo "Watching for 15 seconds..."

sleep 15
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true

echo ""
echo "Test complete"
