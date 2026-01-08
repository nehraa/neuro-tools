#!/usr/bin/env bash
# NeuroOS Bootable ISO with GRUB2 (proper multiboot2 boot)

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
ISO_DIR="grub-iso"
OUTPUT_ISO="NeuroOS-Bootable.iso"

echo "========================================
  NeuroOS GRUB Bootloader ISO
========================================"
echo ""

# Clean and create directory structure
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

# Copy kernel
echo "Copying kernel..."
cp "${KERNEL}" "${ISO_DIR}/boot/neuro-kernel"

# Create GRUB configuration
echo "Creating GRUB configuration..."
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=2
set default=0

# Enable serial console for debugging
serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console

menuentry "NeuroOS" {
    echo "Loading NeuroOS kernel..."
    multiboot2 /boot/neuro-kernel
    echo "Booting NeuroOS..."
    boot
}

menuentry "NeuroOS (Debug)" {
    set debug=all
    echo "Loading NeuroOS kernel in debug mode..."
    multiboot2 /boot/neuro-kernel
    echo "Booting NeuroOS (debug)..."
    boot
}
EOF

# Create the ISO with GRUB
echo "Building bootable ISO with GRUB..."

# Check if grub-mkrescue is available
if command -v grub-mkrescue &> /dev/null; then
    GRUB_CMD="grub-mkrescue"
elif command -v x86_64-elf-grub-mkrescue &> /dev/null; then
    GRUB_CMD="x86_64-elf-grub-mkrescue"
else
    echo "ERROR: grub-mkrescue not found"
    echo "Install with: brew install grub"
    exit 1
fi

${GRUB_CMD} -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | grep -v "^xorriso : WARNING" || true

if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "========================================
  ✓ Bootable ISO Ready!
========================================"
    echo ""
    echo "File: ${OUTPUT_ISO}"
    echo "Size: ${SIZE}"
    echo ""
    echo "To test on M1 Mac:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -serial stdio -m 2G"
    echo ""
    echo "For Intel laptop with Ventoy:"
    echo "  1. Copy ${OUTPUT_ISO} to Ventoy USB"
    echo "  2. Boot laptop from USB"
    echo "  3. Select NeuroOS from Ventoy menu"
    echo ""
    
    # Show kernel info
    echo "Kernel details:"
    file "${KERNEL}"
    objdump -h "${KERNEL}" | grep -E "\.multiboot2|Idx|file format" || true
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

# Clean up
rm -rf "${ISO_DIR}"
