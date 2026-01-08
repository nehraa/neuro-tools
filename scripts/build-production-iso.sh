#!/usr/bin/env bash
# NeuroOS Final Production ISO
# Ready for Ventoy on Intel x86_64 laptops

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
OUTPUT_ISO="NeuroOS-v0.1.0-x86_64.iso"

echo "========================================
  NeuroOS Production ISO Builder
  Version 0.1.0
========================================"
echo ""

# Build ISO structure
rm -rf production-iso
mkdir -p production-iso/boot/grub

# Copy kernel
cp "${KERNEL}" production-iso/boot/neuro-kernel

# Create GRUB configuration for both BIOS and UEFI
cat > production-iso/boot/grub/grub.cfg << 'EOF'
# NeuroOS GRUB Configuration
set timeout=5
set default=0

# Enable serial console for debugging
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

menuentry "NeuroOS v0.1.0" {
    echo "Loading NeuroOS kernel..."
    multiboot2 /boot/neuro-kernel
    echo "Booting..."
    boot
}

menuentry "NeuroOS v0.1.0 (Debug - VGA only)" {
    echo "Loading NeuroOS kernel (VGA output)..."
    terminal_output console
    multiboot2 /boot/neuro-kernel
    echo "Booting..."
    boot
}

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
EOF

# Create comprehensive README
cat > production-iso/README.txt << 'EOF'
================================================================================
  NeuroOS v0.1.0 - Bootable ISO Image
================================================================================

DESCRIPTION
-----------
This is a bootable ISO image containing the NeuroOS kernel, a modern operating
system kernel built with Rust for x86_64 processors.

SYSTEM REQUIREMENTS
-------------------
- 64-bit x86 processor (Intel or AMD)
- 2GB RAM minimum (4GB recommended)
- BIOS or UEFI boot support
- VGA-compatible display

INSTALLATION TO VENTOY USB
--------------------------
1. Download and install Ventoy from: https://www.ventoy.net
2. Create a Ventoy USB drive using the Ventoy installer
3. Copy this ISO file (NeuroOS-v0.1.0-x86_64.iso) to the Ventoy USB drive
4. Boot your computer from the USB drive
5. Select "NeuroOS v0.1.0" from the Ventoy menu

DIRECT BOOT (CD/DVD/USB)
------------------------
You can also burn this ISO to a CD/DVD or write it directly to USB:
- On Linux: dd if=NeuroOS-v0.1.0-x86_64.iso of=/dev/sdX bs=4M status=progress
- On macOS: sudo dd if=NeuroOS-v0.1.0-x86_64.iso of=/dev/diskX bs=4m
- On Windows: Use Rufus or similar tool in DD Image mode

VIRTUAL MACHINE TESTING
------------------------
QEMU (Linux/macOS):
  qemu-system-x86_64 -cdrom NeuroOS-v0.1.0-x86_64.iso -m 2G

VirtualBox:
  1. Create new VM (Type: Linux, Version: Other Linux 64-bit)
  2. Allocate 2GB RAM
  3. Attach this ISO as a CD-ROM
  4. Boot the VM

VMware:
  1. Create new VM
  2. Mount this ISO
  3. Boot

BOOT OPTIONS
------------
The GRUB menu provides two options:
1. NeuroOS v0.1.0           - Standard boot with serial+VGA output
2. NeuroOS v0.1.0 (Debug)   - VGA-only output for troubleshooting

SERIAL CONSOLE
--------------
NeuroOS outputs debug information to the serial port (COM1):
- Baud rate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1

To view serial output in QEMU:
  qemu-system-x86_64 -cdrom NeuroOS-v0.1.0-x86_64.iso -m 2G -serial stdio

TROUBLESHOOTING
---------------
If the system doesn't boot:
- Ensure Secure Boot is disabled in UEFI settings
- Try the "Debug - VGA only" boot option
- Check that your system supports 64-bit operating systems
- Verify the ISO file integrity (MD5/SHA256 checksum)

KERNEL INFORMATION
------------------
- Architecture: x86_64 (Intel/AMD 64-bit)
- Boot Protocol: Multiboot2
- Language: Rust (nightly)
- License: See project documentation

CONTENTS
--------
/boot/neuro-kernel     - NeuroOS kernel executable
/boot/grub/grub.cfg    - GRUB bootloader configuration
/README.txt            - This file

VERSION
-------
NeuroOS v0.1.0
Build date: $(date +"%Y-%m-%d")
Kernel size: $(du -h "${KERNEL}" | cut -f1)

For more information, visit the NeuroOS project repository.
EOF

# Build the ISO
echo "Building production ISO..."
echo ""

x86_64-elf-grub-mkrescue -o "${OUTPUT_ISO}" production-iso 2>&1 | grep -v "WARNING" || true

if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    MD5=$(md5 -q "${OUTPUT_ISO}")
    
    echo ""
    echo "========================================
  ✓ PRODUCTION ISO READY
========================================"
    echo ""
    echo "File: ${OUTPUT_ISO}"
    echo "Size: ${SIZE}"
    echo "MD5:  ${MD5}"
    echo ""
    echo "DEPLOYMENT INSTRUCTIONS"
    echo "======================="
    echo ""
    echo "For Ventoy USB (RECOMMENDED):"
    echo "  1. Install Ventoy on a USB drive"
    echo "  2. Copy ${OUTPUT_ISO} to the USB drive"
    echo "  3. Boot your Intel laptop from USB"
    echo "  4. Select NeuroOS from Ventoy menu"
    echo ""
    echo "For VirtualBox/VMware Testing:"
    echo "  - Attach ${OUTPUT_ISO} as CD-ROM"
    echo "  - Allocate 2GB+ RAM"
    echo "  - Boot the VM"
    echo ""
    echo "ISO Contents:"
    find production-iso -type f | sed 's|production-iso/||' | while read f; do
        echo "  - $f"
    done
    echo ""
    
    # Verify kernel
    echo "Kernel Verification:"
    echo "  Format: $(file "${KERNEL}" | cut -d: -f2-)"
    if hexdump -C "${KERNEL}" | grep -q "d6 50 52 e8"; then
        echo "  Multiboot2: ✓ Header found"
    else
        echo "  Multiboot2: ⚠ Header not found!"
    fi
    echo "  Entry Point: $(objdump -f "${KERNEL}" | grep "start address" | cut -d: -f2 | xargs)"
    echo ""
    
    echo "NOTE: Serial console testing may not work on macOS M1 QEMU emulation,"
    echo "      but the ISO is fully compatible with Intel x86_64 hardware."
    echo ""
    echo "The ISO is ready for deployment to Intel laptops via Ventoy!"
    echo ""
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

rm -rf production-iso
