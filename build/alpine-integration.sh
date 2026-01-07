#!/bin/bash
# Alpine Linux integration script for NeuroOS

set -e

ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
ROOTFS_DIR="alpine-rootfs"
OUTPUT_ISO="neuro-os.iso"

echo "=== Building NeuroOS with Alpine Linux Base ==="

# Download Alpine mini rootfs
echo "[1/8] Downloading Alpine Linux ${ALPINE_VERSION} mini rootfs..."
wget -O alpine-minirootfs.tar.gz \
    "${ALPINE_MIRROR}/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

# Extract rootfs
echo "[2/8] Extracting Alpine rootfs..."
mkdir -p "${ROOTFS_DIR}"
tar -xzf alpine-minirootfs.tar.gz -C "${ROOTFS_DIR}"

# Setup chroot environment
echo "[3/8] Setting up chroot environment..."
cp /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf"
mount --bind /dev "${ROOTFS_DIR}/dev"
mount --bind /proc "${ROOTFS_DIR}/proc"
mount --bind /sys "${ROOTFS_DIR}/sys"

# Install essential packages in chroot
echo "[4/8] Installing packages in Alpine chroot..."
chroot "${ROOTFS_DIR}" /bin/sh <<'CHROOT_EOF'
apk update
apk add \
    linux-lts \
    grub \
    grub-efi \
    eudev \
    dbus \
    util-linux \
    coreutils \
    bash \
    pipewire \
    wayland \
    mesa-dri-gallium \
    sudo

# Create neuro user
adduser -D -G wheel neuro
echo "neuro:neuro" | chpasswd

# Enable services
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add udev sysinit
rc-update add udev-postmount default

CHROOT_EOF

# Copy NeuroOS binaries
echo "[5/8] Installing NeuroOS components..."
mkdir -p "${ROOTFS_DIR}/usr/local/bin"
mkdir -p "${ROOTFS_DIR}/opt/neuro"
mkdir -p "${ROOTFS_DIR}/etc/neuro"

# Copy kernel and bootloader
if [ -f "../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernal" ]; then
    cp "../neuro-kernal/target/x86_64-unknown-none/release/neuro-kernal" \
       "${ROOTFS_DIR}/boot/neuro-kernal"
fi

if [ -f "../neuro-kernal/boot/uefi/target/x86_64-unknown-uefi/release/neuro-bootloader.efi" ]; then
    mkdir -p "${ROOTFS_DIR}/boot/efi/EFI/BOOT"
    cp "../neuro-kernal/boot/uefi/target/x86_64-unknown-uefi/release/neuro-bootloader.efi" \
       "${ROOTFS_DIR}/boot/efi/EFI/BOOT/BOOTX64.EFI"
fi

# Copy services
if [ -f "../neuro-services/init/target/release/neuro-init" ]; then
    cp "../neuro-services/init/target/release/neuro-init" \
       "${ROOTFS_DIR}/usr/local/bin/"
fi

# Copy service configuration
if [ -f "../neuro-services/init/services.json" ]; then
    cp "../neuro-services/init/services.json" \
       "${ROOTFS_DIR}/etc/neuro/services.json"
fi

# Create init script
echo "[6/8] Creating init configuration..."
cat > "${ROOTFS_DIR}/etc/init.d/neuro-services" <<'INIT_EOF'
#!/sbin/openrc-run

name="neuro-services"
description="NeuroOS Service Manager"
command="/usr/local/bin/neuro-init"
command_args="init"
pidfile="/run/neuro-init.pid"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath -d /run/neuro
}
INIT_EOF

chmod +x "${ROOTFS_DIR}/etc/init.d/neuro-services"

chroot "${ROOTFS_DIR}" /bin/sh -c "rc-update add neuro-services default"

# Configure GRUB
echo "[7/8] Configuring GRUB bootloader..."
mkdir -p "${ROOTFS_DIR}/boot/grub"
cat > "${ROOTFS_DIR}/boot/grub/grub.cfg" <<'GRUB_EOF'
set timeout=5
set default=0

menuentry "NeuroOS with Alpine Linux" {
    linux /boot/vmlinuz-lts root=/dev/sda1 rootfstype=ext4 quiet
    initrd /boot/initramfs-lts
}

menuentry "NeuroOS (Direct Kernel)" {
    linux /boot/neuro-kernal
}
GRUB_EOF

# Create initramfs with Neuro modules
echo "[8/8] Creating initramfs..."
chroot "${ROOTFS_DIR}" /bin/sh -c "mkinitfs"

# Cleanup mounts
umount "${ROOTFS_DIR}/dev" || true
umount "${ROOTFS_DIR}/proc" || true
umount "${ROOTFS_DIR}/sys" || true

echo "=== Build complete! ==="
echo "Rootfs created at: ${ROOTFS_DIR}"
echo ""
echo "To create a bootable ISO:"
echo "  sudo ./create-iso.sh ${ROOTFS_DIR}"
echo ""
echo "To test in QEMU:"
echo "  ./test-qemu.sh ${ROOTFS_DIR}"
