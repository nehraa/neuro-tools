#!/usr/bin/env bash
# Create minimal initramfs for NeuroOS
# This allows QEMU to boot the kernel directly with -kernel/-initrd

set -euo pipefail

BUILD_DIR="/tmp/neuro-initramfs-build.$$"
OUTPUT_INITRD="neuro-initrd.img"

echo "========================================"
echo "  NeuroOS Initramfs Builder"
echo "========================================"
echo ""

# Create minimal initramfs structure
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"/{bin,lib,dev,proc,sys,etc,run}

# Create minimal init script
cat > "${BUILD_DIR}/init" << 'EOF'
#!/bin/sh
# Minimal NeuroOS init
echo "NeuroOS booting..."
echo "Kernel command: $(cat /proc/cmdline)"

# Mount kernel filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "NeuroOS initialized. Kernel running."
echo ""
echo "System ready. Type 'exit' to halt."

# Drop to shell
exec /bin/sh
EOF
chmod +x "${BUILD_DIR}/init"

# Create a minimal shell alternative if sh not available
cat > "${BUILD_DIR}/bin/sh" << 'EOF'
#!/bin/true
# Placeholder shell
EOF
chmod +x "${BUILD_DIR}/bin/sh"

# Pack into cpio initramfs
echo "Creating initramfs..."
cd "${BUILD_DIR}"
find . -print0 | cpio -0 -H newc -o | gzip > "/tmp/initramfs-temp.gz"
cd - > /dev/null
mv /tmp/initramfs-temp.gz "${OUTPUT_INITRD}"

SIZE=$(du -h "${OUTPUT_INITRD}" | cut -f1)
echo "✓ Initramfs created: ${OUTPUT_INITRD} (${SIZE})"
echo ""
echo "To boot in QEMU:"
echo "  qemu-system-x86_64 -kernel ../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel \\"
echo "    -initrd ${OUTPUT_INITRD} -m 2G -serial stdio -display none -append console=ttyS0"
echo ""

# Cleanup
rm -rf "${BUILD_DIR}"
