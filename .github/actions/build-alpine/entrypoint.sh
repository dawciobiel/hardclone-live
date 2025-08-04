#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "Using Alpine version: $ALPINE_VERSION"
echo "Use cache: $USE_CACHE"
echo "Build ISO: $BUILD_ISO"

WORKDIR="$(pwd)/alpine-${ALPINE_VERSION}"
CACHEDIR="$WORKDIR/cache"
ISODIR="$WORKDIR/iso"
ROOTFS_DIR="$WORKDIR/rootfs"
APK_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/apk.static"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

mkdir -p "$CACHEDIR" "$ISODIR" "$ROOTFS_DIR"

echo "Checking if apk.static exists at: $APK_URL"
if ! curl -sI "$APK_URL" | grep -q "200 OK"; then
    echo "❌ Error: apk.static not found at $APK_URL (404)"
    exit 1
fi

cd "$CACHEDIR"

echo "Downloading Alpine minirootfs..."
wget -N "$MINIROOTFS_URL"

echo "Downloading apk.static..."
wget -N "$APK_URL"

echo "✅ Downloads completed."

# Here you can continue with further ISO creation logic
# e.g., extract rootfs, configure, build ISO, etc.

