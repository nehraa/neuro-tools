#!/usr/bin/env bash
# NeuroOS Simple Working Bootable ISO
# Uses a minimal approach that's known to work

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
OUTPUT_ISO="NeuroOS-Simple.iso"

echo "========================================
  NeuroOS - Simple Bootable ISO
========================================"
echo ""

# For now, let's just create a minimal ISO that works
# We'll package the kernel and a simple menu

# Create directory structure
rm -rf simple-iso
mkdir -p simple-iso/boot/grub

# Copy kernel
cp "${KERNEL}" simple-iso/boot/neuro-kernel.bin

# Create minimal GRUB config  
cat > simple-iso/boot/grub/grub.cfg << 'EOF'
set timeout=3
set default=0

menuentry "NeuroOS" {
    multiboot2 /boot/neuro-kernel.bin
    boot
}
EOF

# Also create a text file with boot instructions
cat > simple-iso/README.txt << 'EOF'
NeuroOS v0.1.0

This ISO contains the NeuroOS kernel.

To boot:
1. In QEMU: qemu-system-x86_64 -cdrom NeuroOS-Simple.iso -m 2G  
2. In VirtualBox: Attach as CD-ROM and boot
3. On Ventoy USB: Copy this ISO to the USB drive

The kernel will boot and output to serial console (COM1, 115200 baud).

For serial output in QEMU:
qemu-system-x86_64 -cdrom NeuroOS-Simple.iso -m 2G -serial stdio

Kernel file: boot/neuro-kernel.bin
Size: $(du -h "${KERNEL}" | cut -f1)
EOF

# Build ISO
echo "Creating ISO image..."
x86_64-elf-grub-mkrescue -o "${OUTPUT_ISO}" simple-iso 2>&1 | grep -v "WARNING" || true

if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "✓ ISO created: ${OUTPUT_ISO} (${SIZE})"
    echo ""
    echo "Quick test commands:"
    echo "  GUI:    qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G"
    echo "  Serial: qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G -nographic"
    echo ""
    echo "For Ventoy:"
    echo "  1. Copy ${OUTPUT_ISO} to your Ventoy USB drive"
    echo "  2. Boot your Intel laptop from USB"
    echo "  3. Select NeuroOS from the Ventoy menu"
    echo ""
    
    # Show what's in the ISO
    echo "ISO contents:"
    find simple-iso -type f | sed 's|simple-iso/||'
    echo ""
    
    # Verify multiboot header
    echo "Verifying kernel..."
    if hexdump -C "${KERNEL}" | grep -q "d6 50 52 e8"; then
        echo "✓ Multiboot2 header found"
    else
        echo "⚠ Warning: Multiboot2 header not found!"
    fi
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

rm -rf simple-iso
