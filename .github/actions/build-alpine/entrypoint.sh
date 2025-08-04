#!/usr/bin/env bash
set -euo pipefail

ALPINE_VERSION="${1:-3.18}"
USE_CACHE="${2:-false}"
BUILD_ISO="${3:-true}"

echo "Using Alpine version: $ALPINE_VERSION"
echo "Use cache: $USE_CACHE"
echo "Build ISO: $BUILD_ISO"

# --- Create workspace ---
mkdir -p build
cd build

echo "Downloading Alpine minirootfs..."
wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

echo "Downloading apk.static..."
APK_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/apk.static"
wget -q -O apk.static "$APK_URL"

# Check if it's really a binary
if ! file apk.static | grep -q "ELF"; then
    echo "❌ Error: apk.static not found or not a valid binary at $APK_URL"
    exit 1
fi

chmod +x apk.static

# --- Simulated build steps below ---
echo "✅ apk.static verified"
echo "➡️ You can now extract minirootfs, install packages etc."

if [[ "$BUILD_ISO" == "true" ]]; then
    echo "🔨 Building ISO (placeholder logic here)..."
    # TODO: ISO build commands here
else
    echo "ℹ️ Skipping ISO build"
fi
