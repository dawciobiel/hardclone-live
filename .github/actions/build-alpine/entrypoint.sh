#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"
CONFIG_DIR="$REPO_DIR/config"
BUILD_DIR="$REPO_DIR/build"
ISO_ROOT="$BUILD_DIR/iso_root"
CACHE_DIR="$BUILD_DIR/cache"
ISO_DIR="$REPO_DIR/iso"

echo "🔍 Checking required tools..."
for cmd in wget 7z xorriso tar bash proot curl squashfs-tools p7zip-full wget; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required tool '$cmd' not found"
        exit 1
    fi
    echo "✅ $cmd found: $(command -v $cmd)"
done

mkdir -p "$ISO_ROOT" "$CACHE_DIR" "$ISO_DIR"

echo "⬇️ Downloading and extracting Alpine minirootfs..."
ARCH="x86_64"
CACHE_FILE="$CACHE_DIR/alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"
if [ "$USE_CACHE" != "true" ] || [ ! -f "$CACHE_FILE" ]; then
    wget -O "$CACHE_FILE" "https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION.0-$ARCH.tar.gz"
fi
tar -xzf "$CACHE_FILE" -C "$ISO_ROOT"

echo "⚙️ Applying config..."
cp -rv "$CONFIG_DIR/"* "$ISO_ROOT/"

echo "🔧 Customizing ISO root..."
chmod +x "$ISO_ROOT/welcome.sh"

if [ "$BUILD_ISO" = "true" ]; then
    echo "📦 Creating ISO image..."

    # Copy local isohdpfx.bin from tools directory to cache
    cp "$REPO_DIR/tools/isohdpfx.bin" "$CACHE_DIR/isohdpfx.bin"

    BOOT_IMAGE="$CACHE_DIR/isohdpfx.bin"

    xorriso -as mkisofs \
        -o "$ISO_DIR/alpine-$ALPINE_VERSION-cli-live.iso" \
        -isohybrid-mbr "$BOOT_IMAGE" \
        -c boot/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
        -V "ALPINE_LIVE" \
        "$ISO_ROOT"
fi
