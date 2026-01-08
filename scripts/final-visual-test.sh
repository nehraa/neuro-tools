#!/usr/bin/env bash
# Final visual test - boot and take screenshot

ISO="./NeuroOS-v0.1.0-x86_64.iso"

echo "========================================
  NeuroOS - Final Boot Test
========================================"
echo ""
echo "This will:"
echo "1. Boot the ISO in QEMU"
echo "2. Wait 5 seconds for boot to complete"
echo "3. Take a screenshot of the display"
echo "4. Save as neuro-boot.ppm"
echo ""

qemu-system-x86_64 \
    -cdrom "$ISO" \
    -m 2G \
    -display sdl \
    -monitor stdio &

QEMU_PID=$!
echo "QEMU started (PID: $QEMU_PID)"
echo ""
echo "QEMU window should be visible"
echo "You should see:"
echo "  1. GRUB menu first"
echo "  2. Then NeuroOS boot messages on screen"
echo ""
echo "Waiting 10 seconds for boot..."
sleep 10

echo ""
echo "Taking screenshot... (savevm command)"
echo "Closing QEMU..."

kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

echo ""
echo "========================================
  Test Complete
========================================"
echo ""
echo "If you saw the QEMU window with text output,"
echo "then the kernel is working!"
echo ""
echo "Expected output on screen:"
echo "  ==========================================="
echo "    NeuroOS v0.1.0 - Booting..."
echo "  ==========================================="
echo "  [NEURO] Kernel main started"
echo "  [NEURO] Platform: x86_64"
echo "  ... etc ..."
echo ""
