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
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

mkdir -p "$CACHEDIR" "$ISODIR" "$ROOTFS_DIR"

cd "$CACHEDIR"

echo "Downloading Alpine minirootfs..."
wget -N "$MINIROOTFS_URL"

echo "✅ Download completed. Extracting..."

tar -xzf "alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" -C "$ROOTFS_DIR"

echo "✅ Root filesystem prepared at: $ROOTFS_DIR"

# Further ISO preparation logic goes here
