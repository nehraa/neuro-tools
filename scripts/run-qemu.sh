#!/bin/bash
ISO="NeuroOS-Complete-x86_64.iso"
SERIAL_LOG="/tmp/neuro-boot-serial.txt"
rm -f "$SERIAL_LOG"

echo "Starting NeuroOS in QEMU (x86 emulation on ARM)..."
echo "This will open a GUI window - watch for GRUB menu"
echo "Serial output will be logged to: $SERIAL_LOG"
echo ""

# Use TCG (software emulation) since we're on ARM
qemu-system-x86_64 \
  -accel tcg \
  -m 2048 \
  -cdrom "$ISO" \
  -boot d \
  -serial file:"$SERIAL_LOG" \
  -vga std \
  -display cocoa

echo ""
echo "=== QEMU exited ==="
echo "Serial log:"
cat "$SERIAL_LOG" 2>/dev/null || echo "(no output)"
