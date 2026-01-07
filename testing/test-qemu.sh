#!/bin/bash
# QEMU test script for NeuroOS

set -e

ROOTFS_DIR="${1:-alpine-rootfs}"
MEMORY="2G"
CPUS="2"
DISK_SIZE="10G"
DISK_IMAGE="neuro-disk.img"

echo "=== Testing NeuroOS in QEMU ==="

# Create disk image if it doesn't exist
if [ ! -f "${DISK_IMAGE}" ]; then
    echo "[1/4] Creating disk image..."
    qemu-img create -f qcow2 "${DISK_IMAGE}" "${DISK_SIZE}"
    
    # Format and copy rootfs to disk
    echo "[2/4] Installing rootfs to disk..."
    sudo virt-make-fs --format=qcow2 --type=ext4 "${ROOTFS_DIR}" "${DISK_IMAGE}"
fi

# Check if OVMF is available
OVMF_PATH="/usr/share/ovmf/OVMF.fd"
if [ ! -f "${OVMF_PATH}" ]; then
    OVMF_PATH="/usr/share/edk2/ovmf/OVMF_CODE.fd"
fi

echo "[3/4] Starting QEMU..."
echo "Memory: ${MEMORY}, CPUs: ${CPUS}"
echo ""
echo "QEMU keyboard shortcuts:"
echo "  Ctrl+Alt+G    - Release mouse"
echo "  Ctrl+Alt+F    - Toggle fullscreen"
echo "  Ctrl+Alt+1    - Show console"
echo "  Ctrl+A X      - Quit QEMU (from serial console)"
echo ""
echo "Press Enter to start..."
read

echo "[4/4] Launching QEMU..."

qemu-system-x86_64 \
    -machine q35 \
    -cpu host \
    -enable-kvm \
    -m "${MEMORY}" \
    -smp "${CPUS}" \
    -drive file="${DISK_IMAGE}",format=qcow2,if=virtio \
    -bios "${OVMF_PATH}" \
    -serial stdio \
    -vga std \
    -net nic,model=e1000 \
    -net user \
    -device nvme,drive=nvme0,serial=deadbeef \
    -drive id=nvme0,file="${DISK_IMAGE}",if=none,format=qcow2 \
    -device virtio-gpu-pci \
    -usb \
    -device usb-kbd \
    -device usb-mouse \
    -audiodev pa,id=snd0 \
    -device intel-hda \
    -device hda-output,audiodev=snd0 \
    -boot menu=on \
    -monitor telnet:127.0.0.1:55555,server,nowait \
    "$@"

echo ""
echo "=== QEMU session ended ==="
