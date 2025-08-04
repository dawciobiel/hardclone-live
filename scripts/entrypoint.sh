#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

ROOTFS_DIR="alpine-rootfs"
MINIROOTFS="alpine-minirootfs.tar.gz"
ISO_DIR="iso"
KERNEL_BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64"

echo "Using Alpine version: $ALPINE_VERSION"
echo "Use cache: $USE_CACHE"
echo "Build ISO: $BUILD_ISO"

# Make sure proot is installed
if ! command -v proot &>/dev/null; then
  echo "Installing proot..."
  sudo apt-get update && sudo apt-get install -y proot
fi

# Download minirootfs if not cached
if [ "$USE_CACHE" != "true" ] || [ ! -f "$MINIROOTFS" ]; then
  echo "Downloading Alpine minirootfs..."
  curl -sSL -o "$MINIROOTFS" "${KERNEL_BASE_URL}/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
else
  echo "Using cached minirootfs."
fi

# Extract rootfs
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
tar -xzf "$MINIROOTFS" -C "$ROOTFS_DIR"

# Install packages using proot (not chroot)
echo "Installing extra packages into rootfs using proot..."
proot -R "$ROOTFS_DIR" /bin/sh -c "apk update && apk add bash python3 parted mc"

# Build ISO
if [ "$BUILD_ISO" = "true" ]; then
  echo "Building ISO structure..."

  rm -rf "$ISO_DIR"
  mkdir -p "$ISO_DIR/boot/grub"

  echo "Downloading kernel and initramfs..."
  curl -sSL -o "$ISO_DIR/boot/vmlinuz" "${KERNEL_BASE_URL}/vmlinuz-lts"
  curl -sSL -o "$ISO_DIR/boot/initramfs" "${KERNEL_BASE_URL}/initramfs-lts"

  echo "Creating GRUB config..."
  cat <<EOF > "$ISO_DIR/boot/grub/grub.cfg"
set timeout=0
set default=0

menuentry "Alpine Linux $ALPINE_VERSION CLI" {
    linux /boot/vmlinuz
    initrd /boot/initramfs
}
EOF

  echo "Copying root filesystem into ISO..."
  cp -a "$ROOTFS_DIR"/* "$ISO_DIR/"

  echo "Creating ISO..."
  xorriso -as mkisofs -o "alpine-live.iso" \
    -b boot/grub/stage2_eltorito \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$ISO_DIR"

  echo "✅ ISO built successfully: alpine-live.iso"
fi

