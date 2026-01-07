#!/bin/bash
# Build Bootable ISO Image for Neuro-OS
#
# This script creates a bootable ISO image containing:
# - Neuro-OS kernel
# - Initial ramdisk (initrd)
# - Bootloader (GRUB2)
# - System services
# - User space utilities
#
# The resulting ISO can be used for:
# - Testing in QEMU/VirtualBox/VMware
# - Installation on physical hardware
# - USB boot drive creation
#
# Usage:
#   ./build-image.sh [--output FILE] [--debug]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OUTPUT_ISO="${OUTPUT_ISO:-neuro-os.iso}"
WORKSPACE_DIR="${WORKSPACE_DIR:-./neuro-workspace}"
BUILD_DIR="./iso-build"
KERNEL_PATH=""
INITRD_PATH=""
DEBUG_MODE=false

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output)
                OUTPUT_ISO="$2"
                shift 2
                ;;
            --workspace)
                WORKSPACE_DIR="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build a bootable ISO image for Neuro-OS.

OPTIONS:
    --output FILE       Output ISO filename (default: neuro-os.iso)
    --workspace DIR     Workspace directory (default: ./neuro-workspace)
    --debug             Include debug symbols and tools
    --help              Show this help message

REQUIREMENTS:
    - grub2-mkrescue or grub-mkrescue
    - xorriso
    - mtools
    - Built Neuro-OS kernel

EXAMPLES:
    $0
    $0 --output neuro-debug.iso --debug
    $0 --workspace ~/projects/neuro
EOF
}

# Check dependencies
check_dependencies() {
    echo -e "${BLUE}[CHECK]${NC} Checking dependencies..."
    
    local deps=("grub-mkrescue" "xorriso" "mtools")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            # Try grub2 variant
            if [[ "$dep" == "grub-mkrescue" ]] && command -v "grub2-mkrescue" &> /dev/null; then
                continue
            fi
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt-get install grub2-common xorriso mtools"
        exit 1
    fi
    
    echo -e "${GREEN}[✓]${NC} All dependencies found"
}

# Find kernel binary
find_kernel() {
    echo -e "${BLUE}[SEARCH]${NC} Looking for kernel binary..."
    
    # Search paths
    local search_paths=(
        "${WORKSPACE_DIR}/neuro-kernel/target/x86_64-unknown-none/release/neuro-kernel"
        "${WORKSPACE_DIR}/neuro-kernel/target/x86_64-unknown-none/debug/neuro-kernel"
        "${WORKSPACE_DIR}/neuro-kernel/bazel-bin/kernel/neuro-kernel"
        "./bazel-bin/kernel/neuro-kernel"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            KERNEL_PATH="$path"
            echo -e "${GREEN}[✓]${NC} Found kernel: ${KERNEL_PATH}"
            return 0
        fi
    done
    
    echo -e "${RED}[ERROR]${NC} Kernel binary not found"
    echo "Build the kernel first with: cd neuro-kernel && cargo build --release"
    exit 1
}

# Create initrd
create_initrd() {
    echo -e "${BLUE}[BUILD]${NC} Creating initial ramdisk..."
    
    local initrd_dir="${BUILD_DIR}/initrd"
    mkdir -p "$initrd_dir"/{bin,lib,dev,proc,sys,etc}
    
    # Copy essential binaries (if available)
    if [[ -f "${WORKSPACE_DIR}/neuro-services/target/release/init" ]]; then
        cp "${WORKSPACE_DIR}/neuro-services/target/release/init" "${initrd_dir}/bin/"
    fi
    
    # Create init script
    cat > "${initrd_dir}/init" << 'INITEOF'
#!/bin/sh
# Neuro-OS Init Script

echo "Neuro-OS Initializing..."

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Start system services
echo "Starting system services..."

# Drop to shell
exec /bin/sh
INITEOF
    
    chmod +x "${initrd_dir}/init"
    
    # Create initrd archive
    (cd "$initrd_dir" && find . | cpio -H newc -o | gzip) > "${BUILD_DIR}/initrd.img"
    INITRD_PATH="${BUILD_DIR}/initrd.img"
    
    echo -e "${GREEN}[✓]${NC} Created initrd: ${INITRD_PATH}"
}

# Create GRUB configuration
create_grub_config() {
    echo -e "${BLUE}[CONFIG]${NC} Creating GRUB configuration..."
    
    local grub_cfg="${BUILD_DIR}/iso/boot/grub/grub.cfg"
    mkdir -p "$(dirname "$grub_cfg")"
    
    cat > "$grub_cfg" << 'GRUBEOF'
set timeout=5
set default=0

menuentry "Neuro-OS" {
    multiboot /boot/neuro-kernel
    module /boot/initrd.img
    boot
}

menuentry "Neuro-OS (Debug)" {
    multiboot /boot/neuro-kernel console=ttyS0 loglevel=7
    module /boot/initrd.img
    boot
}

menuentry "Neuro-OS (Safe Mode)" {
    multiboot /boot/neuro-kernel single
    module /boot/initrd.img
    boot
}
GRUBEOF
    
    echo -e "${GREEN}[✓]${NC} Created GRUB config"
}

# Build ISO image
build_iso() {
    echo -e "${BLUE}[BUILD]${NC} Creating ISO image..."
    
    # Create ISO directory structure
    mkdir -p "${BUILD_DIR}/iso/boot/grub"
    
    # Copy kernel and initrd
    cp "$KERNEL_PATH" "${BUILD_DIR}/iso/boot/neuro-kernel"
    cp "$INITRD_PATH" "${BUILD_DIR}/iso/boot/initrd.img"
    
    # Create GRUB config
    create_grub_config
    
    # Detect grub-mkrescue variant
    local grub_cmd="grub-mkrescue"
    if ! command -v "$grub_cmd" &> /dev/null; then
        grub_cmd="grub2-mkrescue"
    fi
    
    # Build ISO
    $grub_cmd -o "$OUTPUT_ISO" "${BUILD_DIR}/iso" 2>&1 | grep -v "warning:" || true
    
    if [[ -f "$OUTPUT_ISO" ]]; then
        local size=$(du -h "$OUTPUT_ISO" | cut -f1)
        echo -e "${GREEN}[✓]${NC} Created ISO: ${OUTPUT_ISO} (${size})"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create ISO"
        return 1
    fi
}

# Test ISO in QEMU
test_iso() {
    echo
    echo -e "${BLUE}[TEST]${NC} To test the ISO in QEMU, run:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 512M"
    echo
    echo "Or write to USB drive:"
    echo "  sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress"
    echo "  (Replace /dev/sdX with your USB device)"
}

# Cleanup
cleanup() {
    if [[ "$DEBUG_MODE" != "true" ]]; then
        echo -e "${BLUE}[CLEANUP]${NC} Removing build directory..."
        rm -rf "$BUILD_DIR"
    else
        echo -e "${YELLOW}[DEBUG]${NC} Keeping build directory: ${BUILD_DIR}"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo "========================================"
    echo "  Neuro-OS ISO Builder"
    echo "========================================"
    echo "Output: ${OUTPUT_ISO}"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo "Debug mode: ${DEBUG_MODE}"
    echo "========================================"
    echo
    
    # Setup
    check_dependencies
    find_kernel
    
    # Clean previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Build components
    create_initrd
    
    # Create ISO
    if build_iso; then
        test_iso
        cleanup
        echo -e "${GREEN}✓ ISO build completed successfully!${NC}"
        return 0
    else
        echo -e "${RED}✗ ISO build failed${NC}"
        return 1
    fi
}

# Run with cleanup on exit
trap cleanup EXIT
main "$@"
