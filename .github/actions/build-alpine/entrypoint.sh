#!/usr/bin/env bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"
BASE_DIR="$(pwd)/alpine-${ALPINE_VERSION}"
ROOTFS_DIR="${BASE_DIR}/rootfs"
ISO_DIR="${BASE_DIR}/iso"
OUTPUT_ISO="alpine-${ALPINE_VERSION}-custom.iso"

echo "📦 Alpine version: ${ALPINE_VERSION}"
echo "🗃️ Use cache: ${USE_CACHE}"
echo "📀 Build ISO: ${BUILD_ISO}"

# --- Checking required tools ---
echo "🔍 Checking required tools..."

check_tool() {
  TOOL="$1"
  if command -v "$TOOL" > /dev/null 2>&1; then
    echo "✅ $TOOL found: $($TOOL --version | head -n1)"
  else
    echo "❌ $TOOL NOT found!"
    MISSING=true
  fi
}

MISSING=false
check_tool wget
check_tool 7z
check_tool xorriso
check_tool tar
check_tool bash

if [ "$MISSING" = true ]; then
  echo "❌ One or more required tools are missing. Exiting."
  exit 1
fi

# --- Download and extract rootfs ---
if [ "$USE_CACHE" != "true" ] || [ ! -d "$ROOTFS_DIR" ]; then
  echo "📥 Downloading apk.static and base packages..."
  mkdir -p "$ROOTFS_DIR"
  cd "$BASE_DIR"
  wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
  echo "✅ Download completed. Extracting..."
  tar -xzf "alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" -C "$ROOTFS_DIR"
  echo "✅ Root filesystem prepared at: $ROOTFS_DIR"
  cd -
else
  echo "✅ Using cached rootfs at: $ROOTFS_DIR"
fi

# --- Prepare ISO structure ---
echo "🚧 Preparing ISO structure..."
mkdir -p "$ISO_DIR/boot"

KERNEL_FILE="vmlinuz"
INITRD_FILE="initramfs"

echo "📥 Downloading kernel and initrd..."
KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${KERNEL_FILE}"
INITRD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${INITRD_FILE}"

wget -q -O "$ISO_DIR/boot/$KERNEL_FILE" "$KERNEL_URL" || echo "⚠️ Warning: Kernel file not found at $KERNEL_URL"
wget -q -O "$ISO_DIR/boot/$INITRD_FILE" "$INITRD_URL" || echo "⚠️ Warning: Initrd file not found at $INITRD_URL"

# --- Build ISO ---
if [ "$BUILD_ISO" = "true" ]; then
  echo "🛠️ Creating ISO image..."
  cd "$BASE_DIR"
  xorriso -as mkisofs \
    -o "../${OUTPUT_ISO}" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c boot/boot.cat \
    -b boot/syslinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -V "Alpine-${ALPINE_VERSION}" \
    "$ISO_DIR" || echo "⚠️ Failed to create ISO image!"
  cd -
else
  echo "ℹ️ Skipping ISO build step."
fi
