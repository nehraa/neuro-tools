#!/usr/bin/env bash
# Test GRUB itself - verify GRUB can output to serial

ISO_DIR="grub-test"
OUTPUT_ISO="GRUB-Test.iso"

rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

# Create a GRUB config that just outputs to serial and halts
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console

set timeout=0
set default=0

menuentry "GRUB Serial Test" {
    echo "==================================="
    echo "GRUB IS WORKING!"  
    echo "Serial console is functioning"
    echo "This proves GRUB can output"
    echo "==================================="
    echo ""
    echo "Press any key to halt..."
    read
    halt
}
EOF

# Build ISO
if command -v x86_64-elf-grub-mkrescue &> /dev/null; then
    x86_64-elf-grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | grep -v "WARNING" || true
else
    grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>&1 | grep -v "WARNING" || true
fi

if [ -f "${OUTPUT_ISO}" ]; then
    echo "GRUB test ISO created: ${OUTPUT_ISO}"
    echo ""
    echo "Testing GRUB serial output for 10 seconds..."
    echo ""
    
    (qemu-system-x86_64 -cdrom "${OUTPUT_ISO}" -serial stdio -m 2G -display none 2>&1 & PID=$!; sleep 10; kill $PID 2>/dev/null || true)
    
    echo ""
    echo "If you saw GRUB messages above, serial is working"
fi

rm -rf "${ISO_DIR}"
