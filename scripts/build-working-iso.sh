#!/bin/bash
# Build a working bootable ISO with Alpine Linux + Neuro tools

set -e

BUILD_DIR="neuro-working-build"
OUTPUT_ISO="NeuroOS-Working.iso"
ALPINE_TARBALL="/home/varsha/Desktop/OS/neuro-tools/distro-base/alpine-minirootfs-3.19.0-x86_64.tar.gz"

echo "=========================================="
echo "  Building Working NeuroOS ISO"
echo "=========================================="

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{rootfs,iso/boot/grub}

echo "[1/5] Extracting Alpine Linux..."
tar -xzf "$ALPINE_TARBALL" -C "$BUILD_DIR/rootfs"

echo "[2/5] Setting up test environment..."
mkdir -p "$BUILD_DIR/rootfs/opt/neuro/tests"

# Copy all test scripts
cp /home/varsha/Desktop/OS/neuro-tools/test-scripts/*.sh "$BUILD_DIR/rootfs/opt/neuro/tests/" 2>/dev/null || true
chmod +x "$BUILD_DIR/rootfs/opt/neuro/tests"/*.sh

# Create interactive init
cat > "$BUILD_DIR/rootfs/init" << 'INIT_EOF'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
export TERM=linux

clear
echo ""
echo "================================================"
echo "     NeuroOS v0.1.0 - Interactive System"
echo "================================================"
echo ""

# Mount filesystems
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sys /sys 2>/dev/null
mount -t devtmpfs dev /dev 2>/dev/null
mount -t tmpfs tmp /tmp 2>/dev/null

echo "[BOOT] System initialized"
echo ""
echo "System Info:"
echo "  Kernel: $(uname -r)"
echo "  Machine: $(uname -m)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""
echo "Available Commands:"
echo "  /opt/neuro/tests/test-all.sh     - Run all tests"
echo "  /opt/neuro/tests/benchmark.sh    - Run benchmarks"
echo "  ls /opt/neuro/tests/              - List available tests"
echo "  uname -a                          - System information"
echo "  free -h                           - Memory status"
echo "  ps aux                            - Process list"
echo "  poweroff                          - Shutdown"
echo ""
echo "================================================"
echo ""

# Start shell
export PS1='\[\033[01;32m\]neuro-os\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
exec /bin/sh -l
INIT_EOF
chmod +x "$BUILD_DIR/rootfs/init"

echo "[3/5] Getting Linux kernel..."
# Use host kernel if available, otherwise download
if [ -f "/tmp/vmlinuz-kernel" ]; then
    echo "  Using host kernel"
    cp "/tmp/vmlinuz-kernel" "$BUILD_DIR/iso/boot/vmlinuz"
elif [ -f "/boot/vmlinuz-$(uname -r)" ]; then
    echo "  Using host kernel: $(uname -r)"
    sudo cp "/boot/vmlinuz-$(uname -r)" "$BUILD_DIR/iso/boot/vmlinuz"
    sudo chmod 644 "$BUILD_DIR/iso/boot/vmlinuz"
else
    echo "  Downloading kernel..."
    wget -q -O "$BUILD_DIR/iso/boot/vmlinuz" \
        "http://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/netboot-3.19.0/vmlinuz-lts" || {
        echo "ERROR: Failed to get kernel"
        exit 1
    }
fi

echo "[4/5] Creating initramfs..."
(cd "$BUILD_DIR/rootfs" && find . | cpio -H newc -o 2>/dev/null | gzip -9 > "../iso/boot/initramfs.gz")

echo "[5/5] Creating GRUB bootloader..."
cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" << 'GRUB_EOF'
set timeout=1
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry 'NeuroOS - Interactive Mode' {
    linux /boot/vmlinuz quiet console=tty0 console=ttyS0
    initrd /boot/initramfs.gz
}
GRUB_EOF

echo "Building ISO with GRUB..."
grub-mkrescue -o "$OUTPUT_ISO" "$BUILD_DIR/iso" 2>&1 | grep -vE "(WARNING|NOTE|xorriso)" || true

rm -rf "$BUILD_DIR"

if [ -f "$OUTPUT_ISO" ]; then
    SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
    echo ""
    echo "✓ ISO Ready: $OUTPUT_ISO ($SIZE)"
    echo ""
    echo "Boot with:"
    echo "  qemu-system-x86_64 -cdrom $OUTPUT_ISO -m 2G"
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi
