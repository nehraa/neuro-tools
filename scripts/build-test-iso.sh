#!/bin/bash
# Build a simplified bootable ISO that just runs the test suite

set -e

BUILD_DIR="neuro-test-build"
OUTPUT_ISO="NeuroOS-Tests.iso"
ALPINE_TARBALL="../../neuro-tools/distro-base/alpine-minirootfs-3.19.0-x86_64.tar.gz"

echo "=========================================="
echo "  NeuroOS Test Suite ISO Builder"
echo "=========================================="
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{rootfs,iso/boot/grub}

echo "[1/4] Extracting Alpine Linux base system..."
tar -xzf "$ALPINE_TARBALL" -C "$BUILD_DIR/rootfs" 2>/dev/null

echo "[2/4] Installing test scripts..."
mkdir -p "$BUILD_DIR/rootfs/opt/neuro/tests"

# Copy test scripts
cp ../../neuro-tools/test-scripts/test-all.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-memory.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-containers.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-capabilities.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/benchmark.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/run-tests.sh "$BUILD_DIR/rootfs/opt/neuro/"

chmod +x "$BUILD_DIR/rootfs/opt/neuro/tests"/*.sh
chmod +x "$BUILD_DIR/rootfs/opt/neuro/run-tests.sh"

# Create init script that auto-runs tests
cat > "$BUILD_DIR/rootfs/init" << 'INIT_EOF'
#!/bin/sh
export LANG=C
export LC_ALL=C

echo ""
echo "=========================================="
echo "  NeuroOS Test Suite v0.1.0"
echo "=========================================="
echo ""

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

echo "[INIT] System ready"
echo ""

# Auto-run tests
echo "Starting automated test execution..."
echo ""

/opt/neuro/tests/test-all.sh

echo ""
echo "Running performance benchmarks..."
echo ""

/opt/neuro/tests/benchmark.sh

echo ""
echo "=========================================="
echo "  All Tests Complete!"
echo "=========================================="
echo ""
echo "Results saved to /tmp/"
echo "  - /tmp/neuro-test-results.txt"
echo "  - /tmp/neuro-benchmarks.txt"
echo ""
echo "Available commands:"
echo "  cat /tmp/neuro-test-results.txt  - View test results"
echo "  cat /tmp/neuro-benchmarks.txt    - View benchmarks"
echo "  poweroff                         - Shutdown system"
echo ""

exec /bin/sh
INIT_EOF
chmod +x "$BUILD_DIR/rootfs/init"

echo "[3/4] Building initramfs..."
(cd "$BUILD_DIR/rootfs" && find . | cpio -H newc -o 2>/dev/null | gzip -9 > "../iso/boot/initramfs")

echo "[4/4] Creating GRUB configuration..."
cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" << 'GRUB_EOF'
set timeout=3
set default=0

menuentry 'NeuroOS Test Suite' {
    linux16 /boot/vmlinuz quiet console=ttyS0
    initrd16 /boot/initramfs
}
GRUB_EOF

# We need a minimal kernel - use the host's kernel or download one
if [ -f /boot/vmlinuz ]; then
    cp /boot/vmlinuz "$BUILD_DIR/iso/boot/vmlinuz"
elif [ -f /boot/vmlinuz-$(uname -r) ]; then
    cp /boot/vmlinuz-$(uname -r) "$BUILD_DIR/iso/boot/vmlinuz"
else
    echo "Downloading minimal kernel..."
    wget -O "$BUILD_DIR/iso/boot/vmlinuz" https://boot.netboot.xyz/ipxe/vmlinuz || {
        echo "ERROR: No kernel available"
        exit 1
    }
fi

echo "Creating ISO..."
grub-mkrescue -o "$OUTPUT_ISO" "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true

# Cleanup
rm -rf "$BUILD_DIR"

if [ -f "$OUTPUT_ISO" ]; then
    SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
    
    echo ""
    echo "=========================================="
    echo "  ✓ TEST ISO READY!"
    echo "=========================================="
    echo ""
    echo "File: $OUTPUT_ISO"
    echo "Size: $SIZE"
    echo ""
    echo "Run with:"
    echo "  qemu-system-x86_64 -cdrom $OUTPUT_ISO -m 2G -nographic"
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi
