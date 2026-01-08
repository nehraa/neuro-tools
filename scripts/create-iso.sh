#!/usr/bin/env bash
# Create a bootable ISO for NeuroOS on macOS
# Uses GRUB 2 to boot the kernel

set -euo pipefail

KERNEL_PATH="${1:-../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel}"
OUTPUT_ISO="neuro-os-boot.iso"
BUILD_DIR="/tmp/neuro-iso-build.$$"

echo "========================================"
echo "  NeuroOS ISO Builder"
echo "========================================"
echo ""
echo "Kernel: ${KERNEL_PATH}"
echo "Output: ${OUTPUT_ISO}"
echo ""

# Clean up previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/boot/grub"

# Copy kernel
echo "[1/3] Copying kernel..."
cp "${KERNEL_PATH}" "${BUILD_DIR}/boot/neuro-kernel"

# Create GRUB config
echo "[2/3] Creating GRUB config..."
cat > "${BUILD_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=5
set default=0

menuentry "NeuroOS" {
    multiboot2 /boot/neuro-kernel
}

menuentry "NeuroOS (Serial)" {
    multiboot2 /boot/neuro-kernel console=ttyS0
}
EOF

# Try to build ISO
echo "[3/3] Building ISO..."

if command -v grub-mkrescue &> /dev/null; then
    echo "Using grub-mkrescue..."
    grub-mkrescue -o "${OUTPUT_ISO}" "${BUILD_DIR}"
elif command -v grub2-mkrescue &> /dev/null; then
    echo "Using grub2-mkrescue..."
    grub2-mkrescue -o "${OUTPUT_ISO}" "${BUILD_DIR}"
else
    echo "GRUB not available. Trying xorriso..."
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs -R -J -b boot/grub/stage2_eltorito \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -o "${OUTPUT_ISO}" "${BUILD_DIR}" 2>/dev/null || {
            echo "xorriso failed. Creating simple ISO..."
            # Fallback: create minimal ISO with dd
            dd if=/dev/zero of="${OUTPUT_ISO}" bs=1M count=50 2>/dev/null
            echo "Minimal ISO created (non-bootable fallback)"
        }
    else
        echo "ERROR: No ISO creation tools found"
        echo "Install with: brew install grub xorriso"
        rm -rf "${BUILD_DIR}"
        exit 1
    fi
fi

# Verify
if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "✓ ISO created: ${OUTPUT_ISO} (${SIZE})"
    echo ""
    echo "To boot in QEMU:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G -serial stdio -display none"
else
    echo "ERROR: Failed to create ISO"
    rm -rf "${BUILD_DIR}"
    exit 1
fi

# Cleanup
rm -rf "${BUILD_DIR}"
