#!/usr/bin/env bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

# Directories
ROOT_DIR="$(pwd)"
BUILD_DIR="$ROOT_DIR/build"
ISO_DIR="$ROOT_DIR/iso"
CACHE_DIR="$ROOT_DIR/.cache"

mkdir -p "$BUILD_DIR" "$ISO_DIR" "$CACHE_DIR"

echo "🔍 Checking required tools..."

for TOOL in wget 7z xorriso tar bash proot; do
  if ! command -v "$TOOL" &>/dev/null; then
    echo "❌ Required tool '$TOOL' not found"
    exit 1
  else
    echo "✅ $TOOL found: $($TOOL --version | head -n1)"
  fi
done

# File URLs
BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/x86_64"
MINIROOTFS_NAME="alpine-minirootfs-$ALPINE_VERSION.0-x86_64.tar.gz"
MINIROOTFS_URL="$BASE_URL/$MINIROOTFS_NAME"

# Download minirootfs
if [[ "$USE_CACHE" != "true" || ! -f "$CACHE_DIR/$MINIROOTFS_NAME" ]]; then
  echo "📥 Downloading Alpine minirootfs..."
  echo "🔗 $MINIROOTFS_URL"
  wget -q --show-progress -O "$CACHE_DIR/$MINIROOTFS_NAME" "$MINIROOTFS_URL" || {
    echo "❌ Failed to download minirootfs"
    exit 1
  }
else
  echo "✅ Using cached minirootfs"
fi

# Extract to build directory
rm -rf "$BUILD_DIR/rootfs"
mkdir -p "$BUILD_DIR/rootfs"
tar -xzf "$CACHE_DIR/$MINIROOTFS_NAME" -C "$BUILD_DIR/rootfs"

# Prepare rootfs
echo "🔧 Injecting config into rootfs..."
mkdir -p "$BUILD_DIR/rootfs/root/.config"
echo "Welcome to Alpine $ALPINE_VERSION" > "$BUILD_DIR/rootfs/etc/motd"

# Add your packages, AppImages, scripts, configs here
# Example:
cp -v "$ROOT_DIR/config/welcome.sh" "$BUILD_DIR/rootfs/root/"
chmod +x "$BUILD_DIR/rootfs/root/welcome.sh"

# Emulate chroot with proot to prepare system
echo "🧪 Running setup inside rootfs using proot..."
proot -R "$BUILD_DIR/rootfs" /bin/sh -c "/root/welcome.sh"

# Optional ISO build
if [[ "$BUILD_ISO" == "true" ]]; then
  echo "📦 Creating ISO image..."
  ISO_OUT="$ISO_DIR/alpine-${ALPINE_VERSION}-cli-live.iso"

  mkdir -p "$BUILD_DIR/iso_root/boot/grub"
  cp -a "$BUILD_DIR/rootfs" "$BUILD_DIR/iso_root"

  # Basic grub config
  cat > "$BUILD_DIR/iso_root/boot/grub/grub.cfg" <<EOF
set timeout=5
menuentry "Alpine Linux CLI Live ($ALPINE_VERSION)" {
    linux /boot/vmlinuz root=/dev/null console=tty0 console=ttyS0
    initrd /boot/initramfs
}
EOF

  # Dummy kernel/initramfs (replace with actual ones if needed)
  touch "$BUILD_DIR/iso_root/boot/vmlinuz"
  touch "$BUILD_DIR/iso_root/boot/initramfs"

  xorriso -as mkisofs \
    -o "$ISO_OUT" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c boot.catalog \
    -b boot/grub/grub.cfg \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "$BUILD_DIR/iso_root"

  echo "✅ ISO created at: $ISO_OUT"
else
  echo "ℹ️ Skipping ISO creation."
fi
