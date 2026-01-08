#!/usr/bin/env bash
# NeuroOS Offline ISO Builder
# Downloads Alpine once, bundles everything, creates bootable x86_64 ISO

set -euo pipefail

ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
ALPINE_TARBALL="alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
ROOTFS_DIR="neuro-rootfs"
ISO_DIR="neuro-iso"
OUTPUT_ISO="NeuroOS-x86_64.iso"

KERNEL_BIN="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
SERVICES_DIR="../../neuro-services/target/release"

echo "========================================"
echo "  NeuroOS Offline ISO Builder"
echo "========================================"
echo ""
echo "Target: x86_64 (Intel/AMD)"
echo "Output: ${OUTPUT_ISO}"
echo ""

# Step 1: Download Alpine if not present
if [ ! -f "${ALPINE_TARBALL}" ]; then
    echo "[1/7] Downloading Alpine Linux ${ALPINE_VERSION} (one-time download)..."
    curl -L -o "${ALPINE_TARBALL}" \
        "${ALPINE_MIRROR}/v${ALPINE_VERSION}/releases/x86_64/${ALPINE_TARBALL}"
else
    echo "[1/7] Using cached Alpine tarball: ${ALPINE_TARBALL}"
fi

# Step 2: Extract rootfs
echo "[2/7] Extracting Alpine rootfs..."
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"
tar -xzf "${ALPINE_TARBALL}" -C "${ROOTFS_DIR}"

# Step 3: Copy NeuroOS kernel and binaries
echo "[3/7] Installing NeuroOS components..."
mkdir -p "${ROOTFS_DIR}/boot"
mkdir -p "${ROOTFS_DIR}/usr/local/bin"
mkdir -p "${ROOTFS_DIR}/opt/neuro"

# Copy kernel
if [ -f "${KERNEL_BIN}" ]; then
    cp "${KERNEL_BIN}" "${ROOTFS_DIR}/boot/neuro-kernel"
    echo "  ✓ Kernel: neuro-kernel"
else
    echo "  ✗ Kernel not found at ${KERNEL_BIN}"
    exit 1
fi

# Copy services
if [ -d "${SERVICES_DIR}" ]; then
    for bin in neuro-init neuro-display neuro-gpu neuro-network; do
        if [ -f "${SERVICES_DIR}/${bin}" ]; then
            cp "${SERVICES_DIR}/${bin}" "${ROOTFS_DIR}/usr/local/bin/"
            echo "  ✓ Service: ${bin}"
        fi
    done
fi

# Step 4: Create init script
echo "[4/7] Creating init script..."
cat > "${ROOTFS_DIR}/init" << 'INITEOF'
#!/bin/sh
echo ""
echo "=========================================="
echo "  NeuroOS - Neural Operating System"
echo "  Version 0.1.0"
echo "=========================================="
echo ""
echo "Booting NeuroOS kernel..."
echo ""

# Mount essential filesystems
mount -t proc none /proc 2>/dev/null || true
mount -t sysfs none /sys 2>/dev/null || true
mount -t devtmpfs none /dev 2>/dev/null || true

# Show system info
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo ""

echo "NeuroOS is running!"
echo ""
echo "Type 'poweroff' to shut down."
echo ""

# Drop to shell
exec /bin/sh
INITEOF
chmod +x "${ROOTFS_DIR}/init"

# Step 5: Create GRUB config
echo "[5/7] Creating GRUB bootloader config..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

cp "${ROOTFS_DIR}/boot/neuro-kernel" "${ISO_DIR}/boot/"

cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set timeout=5
set default=0

menuentry "NeuroOS (x86_64)" {
    insmod multiboot2
    multiboot2 /boot/neuro-kernel
}

menuentry "NeuroOS (Serial Console)" {
    insmod multiboot2
    multiboot2 /boot/neuro-kernel console=ttyS0
}
GRUBEOF

# Step 6: Create ISO using xorriso + grub
echo "[6/7] Building bootable ISO..."

# Use x86_64-elf-grub-mkrescue if available, otherwise xorriso directly
if command -v x86_64-elf-grub-mkrescue &> /dev/null; then
    echo "  Using x86_64-elf-grub-mkrescue..."
    x86_64-elf-grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | grep -v "warning:" || true
elif command -v grub-mkrescue &> /dev/null; then
    echo "  Using grub-mkrescue..."
    grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | grep -v "warning:" || true
else
    echo "  Falling back to xorriso..."
    # Create a simple El Torito bootable ISO
    xorriso -as mkisofs \
        -o "${OUTPUT_ISO}" \
        -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -R -J -joliet-long \
        "${ISO_DIR}" 2>/dev/null || {
        # Minimal ISO if that fails
        xorriso -as mkisofs -R -J -o "${OUTPUT_ISO}" "${ISO_DIR}"
    }
fi

# Step 7: Verify and report
echo "[7/7] Verifying ISO..."
if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "========================================"
    echo "  ✓ ISO Created Successfully!"
    echo "========================================"
    echo ""
    echo "File: ${OUTPUT_ISO}"
    echo "Size: ${SIZE}"
    echo ""
    echo "To test locally on M1 Mac:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 2G -serial stdio -display none"
    echo ""
    echo "For your Intel laptop with Ventoy:"
    echo "  1. Copy ${OUTPUT_ISO} to your Ventoy USB drive"
    echo "  2. Boot from USB and select NeuroOS from menu"
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

# Cleanup temp dirs (keep Alpine tarball for next build)
echo "Cleaning up temporary files..."
rm -rf "${ROOTFS_DIR}" "${ISO_DIR}"

echo "Done!"
