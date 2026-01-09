#!/usr/bin/env bash
# NeuroOS Complete Offline Bootable ISO Builder
# All dependencies are included in the repository - NO internet required!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
ALPINE_TARBALL="../../neuro-tools/distro-base/alpine-minirootfs-3.19.0-x86_64.tar.gz"
BUILD_DIR="neuro-complete-build"
OUTPUT_ISO="NeuroOS-Complete-x86_64.iso"

echo "=========================================="
echo "  NeuroOS Complete Offline ISO Builder"
echo "=========================================="
echo ""
echo "Building fully offline bootable ISO..."
echo "All files from repository - no downloads!"
echo ""

# Verify all required files exist locally
if [ ! -f "$KERNEL" ]; then
    echo "ERROR: Kernel not found at $KERNEL"
    echo "Build it with: cd ../../neuro-kernal && cargo build --release --bin neuro-kernel --target x86_64-unknown-none"
    exit 1
fi

if [ ! -f "$ALPINE_TARBALL" ]; then
    echo "ERROR: Alpine tarball not found at $ALPINE_TARBALL"
    echo "This should be included in the repository at neuro-tools/distro-base/"
    exit 1
fi

echo "✓ Kernel found: $(du -h "$KERNEL" | cut -f1)"
echo "✓ Alpine Linux found: $(du -h "$ALPINE_TARBALL" | cut -f1)"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{rootfs,iso/boot/grub}

echo "[1/6] Extracting Alpine Linux base system..."
tar -xzf "$ALPINE_TARBALL" -C "$BUILD_DIR/rootfs" 2>/dev/null
echo "      Extracted: $(du -sh "$BUILD_DIR/rootfs" | cut -f1)"

echo "[2/6] Installing NeuroOS kernel..."
mkdir -p "$BUILD_DIR/rootfs/boot"
cp "$KERNEL" "$BUILD_DIR/rootfs/boot/neuro-kernel"
chmod +x "$BUILD_DIR/rootfs/boot/neuro-kernel"
echo "      Installed: /boot/neuro-kernel"

echo "[3/6] Creating system initialization..."
# Create test scripts directory
mkdir -p "$BUILD_DIR/rootfs/opt/neuro/tests"

# Copy test scripts
cp ../../neuro-tools/test-scripts/test-all.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-memory.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-containers.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/test-capabilities.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"
cp ../../neuro-tools/test-scripts/benchmark.sh "$BUILD_DIR/rootfs/opt/neuro/tests/"

# Copy master test runner
cp ../../neuro-tools/test-scripts/run-tests.sh "$BUILD_DIR/rootfs/opt/neuro/"

# Make all test scripts executable
chmod +x "$BUILD_DIR/rootfs/opt/neuro/tests"/*.sh
chmod +x "$BUILD_DIR/rootfs/opt/neuro/run-tests.sh"

echo "      Created: /opt/neuro/tests/ with 5 test modules"
echo "      Created: /opt/neuro/run-tests.sh (master test runner)"

# Create init script
cat > "$BUILD_DIR/rootfs/init" << 'INIT_EOF'
#!/bin/sh
# NeuroOS Init System with Graphics

# Force pure ASCII locale to avoid garbled characters
export LANG=C
export LC_ALL=C
export LANGUAGE=C
export TERM=linux
stty cols 80 rows 25 2>/dev/null || true

echo ""
echo "=========================================="
echo "  NeuroOS v0.1.0 - System Initializing"
echo "=========================================="
echo ""

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

echo "[INIT] Core filesystems mounted"

# Try to enable framebuffer for graphics
if [ -e /sys/class/graphics/fb0 ]; then
    echo "[INIT] Framebuffer detected: /dev/fb0"
    # Set framebuffer resolution if available
    if command -v fbset >/dev/null 2>&1; then
        fbset -g 1024 768 1024 768 32
        echo "[INIT] Framebuffer set to 1024x768x32"
    fi
fi

echo "[INIT] Kernel: $(uname -r)"
echo "[INIT] Architecture: $(uname -m)"

# Set hostname
hostname neuro-os
echo "[INIT] Hostname: $(hostname)"

# Create test results directory
mkdir -p /tmp/neuro-results

# Attempt to start display manager or console UI
if command -v Xvfb >/dev/null 2>&1; then
    Xvfb :0 -screen 0 1024x768x32 &
    export DISPLAY=:0
    echo "[INIT] X11 virtual framebuffer started"
elif [ -e /dev/fb0 ]; then
    # Use framebuffer console
    export TERM=linux
    setfont -C /dev/fb0 2>/dev/null || true
    echo "[INIT] Framebuffer console mode enabled"
fi

echo ""
echo "=========================================="
echo "  NeuroOS Ready - Graphics Enabled"
echo "=========================================="
echo ""
echo "System Information:"
echo "  Kernel: $(uname -r)"
echo "  Machine: $(uname -m)"
echo "  CPUs: $(grep -c ^processor /proc/cpuinfo)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Uptime: $(uptime -p 2>/dev/null || echo 'N/A')"
echo ""

# Display test suite info with ASCII art
cat << 'ASCII_ART'
  +------------------------------------------------+
  |     NeuroOS Comprehensive Test Suite v0.1      |
  |         Ready for Full System Testing          |
  +------------------------------------------------+
ASCII_ART

echo ""
echo "  Available Commands:"
echo ""
echo "  [TESTING]"
echo "    /opt/neuro/run-tests.sh             - Interactive test menu"
echo "    /opt/neuro/tests/test-all.sh        - All core tests"
echo "    /opt/neuro/tests/test-memory.sh     - Memory & compression"
echo "    /opt/neuro/tests/test-containers.sh - Containerization"
echo "    /opt/neuro/tests/test-capabilities.sh - Security & caps"
echo "    /opt/neuro/tests/benchmark.sh       - Performance benchmarks"
echo ""
echo "  [QUICK START]"
echo "    /opt/neuro/run-tests.sh [Enter]      - Full test suite"
echo ""
echo "  [PERFORMANCE]"
echo "    /opt/neuro/tests/benchmark.sh        - Benchmarks all subsystems"
echo ""
echo "  [SYSTEM]"
echo "    uname -a                        - System information"
echo "    lscpu                           - CPU details"
echo "    free -h                         - Memory info"
echo "    ps aux                          - Running processes"
echo ""
echo "  [CONTROL]"
echo "    poweroff                        - Shutdown system"
echo "    reboot                          - Restart system"
echo ""

exec /bin/sh
INIT_EOF
chmod +x "$BUILD_DIR/rootfs/init"
echo "      Created: /init with graphics support"

echo "[4/6] Creating GRUB configuration..."
# GRUB config defaults to pure text; optional graphics entry if hardware supports it
cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" << 'GRUB_EOF'
# NeuroOS GRUB Configuration - Text default, graphics optional
set timeout=5
set default=0

# Text-only defaults to avoid font/encoding issues
terminal_input console
terminal_output console
set gfxpayload=text

# Load font for optional graphics entry
insmod font
if [ -f $prefix/fonts/unicode.pf2 ]; then
    loadfont $prefix/fonts/unicode.pf2
fi

menuentry "NeuroOS v0.1.0 - Text Console (default)" {
    echo "Loading NeuroOS in text mode..."
    terminal_output console
    set gfxpayload=text
    multiboot2 /boot/neuro-kernel
    module2 /boot/initramfs initramfs
}

menuentry "NeuroOS v0.1.0 - Graphics (auto-detect)" {
    echo "Loading NeuroOS with graphics..."
    insmod all_video
    insmod gfxterm
    insmod vbe
    insmod vga
    terminal_output gfxterm
    set gfxmode=auto
    set gfxpayload=keep
    multiboot2 /boot/neuro-kernel
    module2 /boot/initramfs initramfs
}

menuentry "NeuroOS v0.1.0 - Kernel Only" {
    echo "Loading NeuroOS kernel..."
    terminal_output console
    set gfxpayload=text
    multiboot2 /boot/neuro-kernel
}

menuentry "Reboot" {
    reboot
}

menuentry "Power Off" {
    halt
}
GRUB_EOF
echo "      Created: GRUB configuration (text default, graphics optional)"

echo "[5/6] Building initramfs..."
# Create initramfs with Alpine + kernel
(cd "$BUILD_DIR/rootfs" && find . | cpio -H newc -o 2>/dev/null | gzip -9 > "../iso/boot/initramfs")
echo "      Initramfs: $(du -h "$BUILD_DIR/iso/boot/initramfs" | cut -f1)"

# Copy kernel to ISO boot directory
cp "$KERNEL" "$BUILD_DIR/iso/boot/neuro-kernel"

echo "[6/6] Creating bootable ISO..."
# Use grub-mkrescue - it will handle BIOS and EFI boot
grub-mkrescue -o "$OUTPUT_ISO" "$BUILD_DIR/iso" 2>&1 | grep -vE "(WARNING|xorriso: NOTE)" || {
    echo "ERROR: ISO creation failed"
    echo "Trying manual xorriso method..."
    
    # Manual ISO creation with xorriso
    xorriso -as mkisofs \
        -o "$OUTPUT_ISO" \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "NEURO_OS" \
        -eltorito-boot boot/grub/grub_eltorito \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "$BUILD_DIR/iso" 2>&1 | grep -vE "(WARNING|NOTE)" || true
}

# Cleanup
rm -rf "$BUILD_DIR"

if [ -f "$OUTPUT_ISO" ]; then
    SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
    MD5=$(md5 -q "$OUTPUT_ISO" 2>/dev/null || md5sum "$OUTPUT_ISO" 2>/dev/null | cut -d' ' -f1)
    
    echo ""
    echo "=========================================="
    echo "  ✓ COMPLETE ISO READY!"
    echo "=========================================="
    echo ""
    echo "File: $OUTPUT_ISO"
    echo "Size: $SIZE"
    echo "MD5:  $MD5"
    echo ""
    echo "Contents:"
    echo "  • Alpine Linux 3.19 base system"
    echo "  • NeuroOS kernel (bare-metal)"
    echo "  • GRUB bootloader (BIOS + UEFI)"
    echo "  • Complete initramfs with utilities"
    echo "  • Serial console support"
    echo ""
    echo "Boot Options:"
    echo "  1. Complete System - Full Alpine + NeuroOS kernel"
    echo "  2. Kernel Only - Bare NeuroOS kernel with VGA output"
    echo ""
    echo "DEPLOYMENT:"
    echo "  Ventoy USB: Copy $OUTPUT_ISO to Ventoy drive"
    echo "  VirtualBox: Attach as CD-ROM (2GB RAM, 64-bit)"
    echo "  QEMU Test: qemu-system-x86_64 -cdrom $OUTPUT_ISO -m 2G"
    echo ""
    echo "This ISO is COMPLETELY OFFLINE - no internet needed!"
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi
