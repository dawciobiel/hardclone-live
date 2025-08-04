#!/usr/bin/env bash

set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

echo "🔍 Checking required tools..."

check_tool() {
    local tool="$1"
    local version_cmd="$2"
    if command -v "$tool" &> /dev/null; then
        local version=$($version_cmd 2>&1 || true)
        echo "✅ $tool found: $version"
    else
        echo "❌ $tool NOT found!"
        MISSING_TOOL=true
    fi
}

MISSING_TOOL=false
check_tool wget "wget --version | head -n1"
check_tool 7z "7z | head -n1"
check_tool xorriso "xorriso --version | head -n1"
check_tool tar "tar --version | head -n1"
check_tool bash "bash --version | head -n1"
check_tool proot "proot --version | head -n1"

if [ "$MISSING_TOOL" = true ]; then
    echo "❌ One or more required tools are missing. Exiting."
    exit 1
fi

# Paths
ROOT_DIR="$(pwd)"
BUILD_DIR="$ROOT_DIR/build"
CACHE_DIR="$ROOT_DIR/cache"
ISO_DIR="$ROOT_DIR/iso"
CONFIG_DIR="$ROOT_DIR/config"

# Prepare dirs
mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$ISO_DIR"

# Download minirootfs
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/x86_64/alpine-minirootfs-$ALPINE_VERSION.0-x86_64.tar.gz"
MINIROOTFS_ARCHIVE="$CACHE_DIR/alpine-minirootfs.tar.gz"

if [ "$USE_CACHE" != "true" ] || [ ! -f "$MINIROOTFS_ARCHIVE" ]; then
    echo "⬇️ Downloading Alpine minirootfs..."
    wget -O "$MINIROOTFS_ARCHIVE" "$MINIROOTFS_URL"
else
    echo "✅ Using cached Alpine minirootfs"
fi

# Extract rootfs
ISO_ROOT="$BUILD_DIR/iso_root"
rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT"
tar -xzf "$MINIROOTFS_ARCHIVE" -C "$ISO_ROOT"

# Copy config files
echo "⚙️ Applying config..."
cp -a "$CONFIG_DIR/." "$ISO_ROOT/"

# Chroot-like setup via proot
echo "🔧 Customizing ISO root..."
proot -R "$ISO_ROOT" /bin/sh -c "chmod +x /welcome.sh && ln -sf /welcome.sh /etc/profile"

if [ "$BUILD_ISO" = "true" ]; then
    echo "📦 Creating ISO image..."

    # Set fallback path for isohdpfx.bin
    BOOT_IMAGE="/usr/lib/ISOLINUX/isohdpfx.bin"
    [[ -f "$BOOT_IMAGE" ]] || BOOT_IMAGE="/usr/lib/syslinux/isohdpfx.bin"

    xorriso -as mkisofs \
        -o "$ISO_DIR/alpine-$ALPINE_VERSION-cli-live.iso" \
        -isohybrid-mbr "$BOOT_IMAGE" \
        -c boot/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
        -V "ALPINE_LIVE" \
        "$ISO_ROOT"
fi

echo "✅ Build complete."
