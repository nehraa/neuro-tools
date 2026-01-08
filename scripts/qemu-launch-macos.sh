#!/usr/bin/env bash
# NeuroOS QEMU Launcher for macOS
# Boots the NeuroOS kernel with minimal initramfs

set -euo pipefail

KERNEL_PATH="${1:-../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel}"
INITRD_PATH="${2:-neuro-initrd.img}"
MEMORY="${MEMORY:-2G}"
CPUS="${CPUS:-2}"

echo "========================================"
echo "  NeuroOS QEMU Launcher (macOS)"
echo "========================================"
echo ""
echo "Kernel: ${KERNEL_PATH}"
echo "Initrd: ${INITRD_PATH}"
echo "Memory: ${MEMORY}"
echo "CPUs:   ${CPUS}"
echo ""

# Check if kernel exists
if [ ! -f "${KERNEL_PATH}" ]; then
    echo "ERROR: Kernel not found at ${KERNEL_PATH}"
    exit 1
fi

# Create initramfs if missing
if [ ! -f "${INITRD_PATH}" ]; then
    echo "Creating initramfs..."
    bash create-initramfs.sh
fi

echo "QEMU Controls:"
echo "  Ctrl+A X      - Quit QEMU"
echo "  Ctrl+A C      - Switch to QEMU monitor"
echo ""
echo "Starting QEMU... Press Ctrl+A then X to exit"
echo ""
echo "========================================"
echo ""

# Boot kernel with initramfs (no KVM on macOS, using TCG emulation)
qemu-system-x86_64 \
    -kernel "${KERNEL_PATH}" \
    -initrd "${INITRD_PATH}" \
    -m "${MEMORY}" \
    -smp "${CPUS}" \
    -serial stdio \
    -display none \
    -append "console=ttyS0" \
    "$@"

echo ""
echo "========================================"
echo "  QEMU session ended"
echo "========================================"
