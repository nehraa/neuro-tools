#!/usr/bin/env bash
# Create minimal working ISO with debugging

KERNEL="../../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernel"
ISO_DIR="debug-iso"
OUTPUT_ISO="NeuroOS-Debug.iso"

echo "Creating debug ISO..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

# Copy kernel
cp "${KERNEL}" "${ISO_DIR}/boot/neuro-kernel"

# Create GRUB config with explicit multiboot2
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0

echo "GRUB: Loading NeuroOS..."

menuentry "NeuroOS (Multiboot2)" {
    echo "GRUB: Attempting multiboot2 load..."
    insmod multiboot2
    insmod serial
    serial --unit=0 --speed=115200
    terminal_input serial console
    terminal_output serial console
    
    echo "GRUB: Loading kernel from /boot/neuro-kernel"
    multiboot2 /boot/neuro-kernel
    echo "GRUB: Kernel loaded, booting..."
    boot
}

menuentry "NeuroOS (Linux mode)" {
    echo "GRUB: Attempting Linux boot protocol..."
    insmod linux
    linux /boot/neuro-kernel console=ttyS0
    boot
}
EOF

echo "Building ISO with x86_64-elf-grub-mkrescue..."
x86_64-elf-grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | head -20

if [ -f "${OUTPUT_ISO}" ]; then
    SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)
    echo ""
    echo "✓ Debug ISO created: ${OUTPUT_ISO} (${SIZE})"
    echo ""
    echo "Testing boot..."
    
    # Boot with more verbose output
    qemu-system-x86_64 \
        -cdrom "${OUTPUT_ISO}" \
        -m 2G \
        -serial stdio \
        -display none \
        -boot d &
    
    PID=$!
    echo "QEMU PID: ${PID} (will run for 10 seconds)"
    sleep 10
    kill ${PID} 2>/dev/null || true
    wait ${PID} 2>/dev/null || true
    
    echo ""
    echo "If you saw kernel output above, it worked!"
    echo "If not, GRUB couldn't load the kernel as multiboot2."
else
    echo "ERROR: ISO creation failed"
    exit 1
fi

rm -rf "${ISO_DIR}"
