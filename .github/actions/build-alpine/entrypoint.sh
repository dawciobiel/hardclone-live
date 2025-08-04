#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

# 🔍 Checking required tools
echo "🔍 Checking required tools..."
REQUIRED_CMDS=("wget" "7z" "mkisofs" "tar" "bash")
MISSING=false

for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $cmd found: $($cmd --version 2>&1 | head -n 1)"
    else
        echo "❌ $cmd NOT found!"
        MISSING=true
    fi
done

if [[ "$MISSING" == true ]]; then
    echo "❌ One or more required tools are missing. Exiting."
    exit 1
fi

# 🏗️ Create working directories
BUILD_DIR="/tmp/alpine-build"
ISO_DIR="$BUILD_DIR/iso"
ROOTFS_DIR="$BUILD_DIR/rootfs"
CACHE_DIR="$BUILD_DIR/cache"

mkdir -p "$ISO_DIR" "$ROOTFS_DIR" "$CACHE_DIR"

# 📥 Download apk.static
echo "📥 Downloading apk.static and base packages..."
APK_TOOLS_URL="https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/main/x86_64/apk-tools-static-*.apk"
wget -q -O "$CACHE_DIR/apk-tools-static.apk" "$APK_TOOLS_URL"

if [[ ! -f "$CACHE_DIR/apk-tools-static.apk" ]]; then
    echo "❌ Failed to download apk-tools-static from: $APK_TOOLS_URL"
    exit 1
fi

cd "$CACHE_DIR"
7z x apk-tools-static.apk > /dev/null
tar -xzf apk-tools-static.tar.gz

# 🔧 Continue setup...
# (tu kontynuuj instalację minirootfs, budowanie ISO itd.)

echo "✅ All required tools are available. Proceeding with Alpine Live ISO creation..."
