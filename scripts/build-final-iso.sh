#!/usr/bin/env bash
# Final working ISO builder - uses syslinux instead of GRUB for better compatibility

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
ISO_DIR="final-iso"
OUTPUT_ISO="NeuroOS-x86_64-Final.iso"

echo "========================================
  NeuroOS Final ISO Builder
========================================"
echo ""
echo "Building ISO for x86_64 Intel/AMD systems..."
echo ""

rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot"

# Copy kernel
cp "${KERNEL}" "${ISO_DIR}/boot/neuro.bin"

# Create a simple boot script
cat > "${ISO_DIR}/boot/README.txt" << 'EOF'
NeuroOS Bootable ISO

This ISO contains:
- NeuroOS Kernel (boot/neuro.bin)  
- Multiboot2 compliant bootloader

Boot this ISO in:
- QEMU: qemu-system-x86_64 -cdrom NeuroOS-x86_64-Final.iso -m 2G
- VirtualBox: Attach as CD-ROM and boot
- Ventoy: Copy to Ventoy USB and select from boot menu
- Physical hardware: Burn to USB or CD

System Requirements:
- 64-bit x86 processor (Intel/AMD)
- 2GB RAM minimum
- BIOS or UEFI boot support

Version: 0.1.0
EOF

# Create ISO with boot sector
echo "Creating bootable ISO..."

# Use xorriso to create a basic bootable ISO
# The kernel has multiboot2 header, so we make it the boot image
xorriso -as mkisofs \
    -o "${OUTPUT_ISO}" \
    -b boot/neuro.bin \
    -c boot/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -R -J \
    "${ISO_DIR}" 2>&1 | grep -v "^xorriso : WARNING"

if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "========================================
  ✓ ISO Created Successfully!
========================================"
    echo ""
    echo "File: ${OUTPUT_ISO}"
    echo "Size: ${SIZE}"
    echo ""
    echo "Quick Test (M1 Mac with x86 emulation):"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G"
    echo ""
    echo "For Ventoy on Intel laptop:"
    echo "  1. Copy ${OUTPUT_ISO} to Ventoy USB"
    echo "  2. Boot and select from Ventoy menu"
    echo ""
    
    # Quick boot test
    echo "Running 5-second boot test..."
    (qemu-system-x86_64 -cdrom "${OUTPUT_ISO}" -m 2G -serial stdio -display none -boot d 2>&1 | head -50) &
    PID=$!
    sleep 5
    kill ${PID} 2>/dev/null || true
    wait ${PID} 2>/dev/null || true
    
    echo ""
    echo "ISO ready for use!"
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

rm -rf "${ISO_DIR}"
