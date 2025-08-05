#!/bin/bash
set -e

# Default version if not provided
ALPINE_VERSION="${1:-3.20}"
USE_CACHE="${2:-true}"
BUILD_ISO="${3:-true}"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

# Set up directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_DIR="$REPO_DIR/config"
BUILD_DIR="$REPO_DIR/build"
ISO_ROOT="$BUILD_DIR/iso_root"
CACHE_DIR="$BUILD_DIR/cache"
ISO_DIR="$REPO_DIR/iso"
TOOLS_DIR="$REPO_DIR/tools"

mkdir -p "$ISO_ROOT" "$CACHE_DIR" "$ISO_DIR"

echo "🔍 Checking required tools..."
for cmd in wget 7z xorriso tar bash proot curl mksquashfs; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required tool '$cmd' not found"
        exit 1
    fi
    echo "✅ $cmd found: $(command -v $cmd)"
done

echo "📥 Using local Syslinux BIOS boot files..."
cp "$REPO_DIR/tools/isohdpfx.bin" "$CACHE_DIR/isohdpfx.bin"

ARCH="x86_64"
CACHE_FILE="$CACHE_DIR/alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"

echo "⬇️ Downloading and extracting Alpine minirootfs..."
if [ "$USE_CACHE" != "true" ] || [ ! -f "$CACHE_FILE" ]; then
    # Try with .0 suffix first
    BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/$ARCH"
    FILE_NAME="alpine-minirootfs-$ALPINE_VERSION.0-$ARCH.tar.gz"

    echo "🌐 Attempting download: $BASE_URL/$FILE_NAME"
    if ! wget -O "$CACHE_FILE" "$BASE_URL/$FILE_NAME"; then
        echo "⚠️ Failed to fetch .0 suffix, trying without suffix..."
        FILE_NAME="alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"
        wget -O "$CACHE_FILE" "$BASE_URL/$FILE_NAME"
    fi
else
    echo "📦 Using cached minirootfs..."
fi

echo "📦 Extracting Alpine base system..."
tar -xzf "$CACHE_FILE" -C "$ISO_ROOT"

echo "⚙️ Applying configuration..."
cp -rv "$CONFIG_DIR/"* "$ISO_ROOT/"

echo "🔧 Customizing ISO root..."
chmod +x "$ISO_ROOT/welcome.sh"

if [ "$BUILD_ISO" = "true" ]; then
    echo "📀 Creating ISO image..."

    BOOT_IMAGE="$CACHE_DIR/isohdpfx.bin"
    if [ ! -f "$BOOT_IMAGE" ]; then
        echo "❌ Missing isohdpfx.bin in $CACHE_DIR"
        exit 1
    fi

    # Ensure syslinux files are inside ISO root at boot/syslinux/
    SYSROOT="$ISO_ROOT/boot/syslinux"
    mkdir -p "$SYSROOT"
    cp "$REPO_DIR/iso/boot/isolinux/isolinux.bin" "$SYSROOT/"
    cp "$REPO_DIR/iso/boot/isolinux/ldlinux.c32" "$SYSROOT/"
    cp "$REPO_DIR/iso/boot/isolinux/memdisk" "$SYSROOT/"
    cp "$REPO_DIR/iso/boot/isolinux/menu.c32" "$SYSROOT/"
    cp "$REPO_DIR/iso/boot/isolinux/vesamenu.c32" "$SYSROOT/"

    xorriso -as mkisofs \
        -o "$ISO_DIR/alpine-$ALPINE_VERSION-cli-live.iso" \
        -isohybrid-mbr "$BOOT_IMAGE" \
        -c boot/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
        -V "ALPINE_LIVE" \
        "$ISO_ROOT"

    echo "✅ ISO image created: $ISO_DIR/alpine-$ALPINE_VERSION-cli-live.iso"
fi
