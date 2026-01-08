#!/usr/bin/env bash
# Quick bootable ISO creator for NeuroOS (macOS compatible)

set -euo pipefail

KERNEL_PATH="/Users/abhinavnehra/Desktop/NeuroOS/remote-clones/neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
BUILD_DIR="/tmp/neuro-iso-build"
OUTPUT_ISO="/Users/abhinavnehra/Desktop/NeuroOS/neuro-os.iso"

echo "========================================"
echo "  NeuroOS ISO Builder"
echo "========================================"

# Clean and create build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/boot/grub"
mkdir -p "${BUILD_DIR}/iso"

# Copy kernel
echo "[1/3] Copying kernel..."
cp "${KERNEL_PATH}" "${BUILD_DIR}/boot/neuro-kernel"

# Create GRUB config
echo "[2/3] Creating GRUB configuration..."
cat > "${BUILD_DIR}/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0

menuentry "NeuroOS" {
    multiboot /boot/neuro-kernel
    boot
}
EOF

# Try to create ISO if grub-mkrescue is available
echo "[3/3] Creating ISO..."
if command -v grub-mkrescue &> /dev/null; then
    grub-mkrescue -o "${OUTPUT_ISO}" "${BUILD_DIR}" 2>&1 | grep -v "warning:" || true
    echo ""
    echo "✓ ISO created: ${OUTPUT_ISO}"
    echo ""
    echo "Boot with:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G -serial stdio -display none"
else
    echo ""
    echo "⚠️  grub-mkrescue not available on macOS."
    echo "Creating a minimal boot directory instead."
    echo ""
    echo "Boot directly with:"
    echo "  qemu-system-x86_64 -kernel ${KERNEL_PATH} -m 2G -serial stdio"
fi
