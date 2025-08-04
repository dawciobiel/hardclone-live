#!/usr/bin/env bash
set -euo pipefail

ALPINE_VERSION="${1:-3.18}"
USE_CACHE="${2:-true}"
BUILD_ISO="${3:-true}"

ROOT_DIR="$(pwd)"
WORKDIR="$ROOT_DIR/alpine-$ALPINE_VERSION"
ROOTFS_DIR="$WORKDIR/rootfs"
ISO_DIR="$WORKDIR/iso"
ISO_OUTPUT="$ROOT_DIR/alpine-$ALPINE_VERSION-custom.iso"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

echo "🔍 Checking required tools..."
for tool in wget 7z xorriso tar bash; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool found: $($tool --version 2>/dev/null | head -n 1 || echo OK)"
    else
        echo "❌ $tool is not installed. Exiting."
        exit 1
    fi
done

mkdir -p "$ROOTFS_DIR" "$ISO_DIR/boot" "$ISO_DIR/syslinux"

MINIROOTFS="alpine-minirootfs-$ALPINE_VERSION-x86_64.tar.gz"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/x86_64/$MINIROOTFS"

if [[ "$USE_CACHE" != "true" || ! -f "$MINIROOTFS" ]]; then
    echo "📥 Downloading apk.static and base packages..."
    wget -q --show-progress "$MINIROOTFS_URL" -O "$MINIROOTFS"
else
    echo "💾 Using cached minirootfs: $MINIROOTFS"
fi

echo "✅ Download completed. Extracting..."
tar -xzf "$MINIROOTFS" -C "$ROOTFS_DIR"
echo "✅ Root filesystem prepared at: $ROOTFS_DIR"

echo "🚧 Preparing ISO structure..."

# Copy rootfs content
cp -a "$ROOTFS_DIR/." "$ISO_DIR/"

echo "📥 Downloading kernel and initrd..."
KERNEL_NAME="vmlinuz-virt"
INITRD_NAME="initramfs-virt"

KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/x86_64/$KERNEL_NAME"
INITRD_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/x86_64/$INITRD_NAME"

wget -q --show-progress "$KERNEL_URL" -O "$ISO_DIR/boot/$KERNEL_NAME" || echo "⚠️ Warning: Kernel file not found at $KERNEL_URL"
wget -q --show-progress "$INITRD_URL" -O "$ISO_DIR/boot/$INITRD_NAME" || echo "⚠️ Warning: Initrd file not found at $INITRD_URL"

echo "📥 Downloading syslinux bootloader..."
SYSLINUX_PKG="syslinux-6.04_pre1-r4.apk"
wget -q "https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/main/x86_64/$SYSLINUX_PKG"
mkdir -p syslinux-extract
7z x "$SYSLINUX_PKG" -osyslinux-extract > /dev/null
7z x "syslinux-extract/data.tar.gz" -osyslinux-extract > /dev/null

cp syslinux-extract/usr/share/syslinux/isolinux.bin "$ISO_DIR/syslinux/"
cp syslinux-extract/usr/share/syslinux/ldlinux.c32 "$ISO_DIR/syslinux/"
cp syslinux-extract/usr/share/syslinux/libcom32.c32 "$ISO_DIR/syslinux/"
cp syslinux-extract/usr/share/syslinux/libutil.c32 "$ISO_DIR/syslinux/"
cp syslinux-extract/usr/share/syslinux/menu.c32 "$ISO_DIR/syslinux/"
cp syslinux-extract/usr/share/syslinux/vesamenu.c32 "$ISO_DIR/syslinux/"

cp syslinux-extract/usr/lib/syslinux/isohdpfx.bin "$ISO_DIR/"

cat > "$ISO_DIR/syslinux/isolinux.cfg" <<EOF
UI vesamenu.c32
PROMPT 0
TIMEOUT 50
DEFAULT alpine

LABEL alpine
  KERNEL /boot/$KERNEL_NAME
  INITRD /boot/$INITRD_NAME
  APPEND initrd=/boot/$INITRD_NAME console=ttyS0
EOF

echo "🛠️ Creating ISO image..."
cd "$ISO_DIR"

xorriso \
  -as mkisofs \
  -o "$ISO_OUTPUT" \
  -isohybrid-mbr ./isohdpfx.bin \
  -c syslinux/boot.cat \
  -b syslinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -V "ALPINE_LIVE" \
  -eltorito-alt-boot \
  -e boot/$INITRD_NAME \
  -no-emul-boot \
  -isohybrid-apm-hfsplus \
  -isohybrid-gpt-basdat \
  .

echo "✅ ISO image created at $ISO_OUTPUT"
