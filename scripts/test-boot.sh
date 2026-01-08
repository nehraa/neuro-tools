#!/bin/bash
ISO="/Users/abhinavnehra/Desktop/NeuroOS/remote-clones/neuro-tools/scripts/NeuroOS-Complete-x86_64.iso"
rm -f /tmp/neuro-serial.log
echo "Booting NeuroOS ISO in QEMU..."
echo "Watch the QEMU window for GRUB menu and boot process"
echo "Press Ctrl+C here when done or QEMU exits"
qemu-system-x86_64 -cdrom "$ISO" -m 2G -boot d -serial file:/tmp/neuro-serial.log -monitor stdio
echo ""
echo "Serial output:"
cat /tmp/neuro-serial.log 2>/dev/null || echo "No serial output"
