#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

WORKDIR="$(pwd)/work"
ISODIR="$WORKDIR/iso"
CACHEDIR="$WORKDIR/cache"
OUTDIR="$(pwd)/out"

mkdir -p "$ISODIR" "$CACHEDIR" "$OUTDIR"

echo "📥 Downloading apk.static and base packages..."

BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64"

if [[ "$USE_CACHE" == "true" && -f "$CACHEDIR/apk.static" ]]; then
    echo "✅ Using cached apk.static"
else
    wget -q --show-progress "$BASE_URL/apk-tools-static-2.12.10-r3.apk" -O "$CACHEDIR/apk.apk"
    tar -xzf "$CACHEDIR/apk.apk" -C "$CACHEDIR" sbin/apk.static
fi

echo "📦 Extracting minirootfs..."
if [[ "$USE_CACHE" == "true" && -d "$CACHEDIR/rootfs" ]]; then
    echo "✅ Using cached rootfs"
    cp -a "$CACHEDIR/rootfs" "$ISODIR/rootfs"
else
    mkdir -p "$WORKDIR/rootfs"
    "$CACHEDIR/sbin/apk.static" \
        --root "$WORKDIR/rootfs" \
        --repository "$BASE_URL" \
        --initdb add alpine-base bash coreutils util-linux e2fsprogs parted mc nano python3
    cp -a "$WORKDIR/rootfs" "$CACHEDIR/rootfs"
    cp -a "$WORKDIR/rootfs" "$ISODIR/rootfs"
fi

echo "🚧 Preparing ISO structure..."
mkdir -p "$ISODIR/boot"

echo "📥 Downloading official Alpine ISO..."
ISO_NAME="alpine-standard-${ALPINE_VERSION}.0-x86_64.iso"
wget -q --show-progress "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${ISO_NAME}"

echo "📂 Extracting kernel and initramfs from ISO using 7z..."
mkdir -p "$WORKDIR/iso"
7z x "$ISO_NAME" -o"$WORKDIR/iso" > /dev/null

cp "$WORKDIR/iso/boot/vmlinuz-vanilla" "$ISODIR/boot/vmlinuz"
cp "$WORKDIR/iso/boot/initramfs-vanilla" "$ISODIR/boot/initrd"

if [[ "$BUILD_ISO" == "true" ]]; then
    echo "📀 Building custom ISO..."
    mkisofs -o "$OUTDIR/alpine-custom.iso" \
        -b boot/syslinux/isolinux.bin \
        -c boot/syslinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -J -R -V "ALPINE_CUSTOM" "$ISODIR"
    echo "✅ ISO built: $OUTDIR/alpine-custom.iso"
else
    echo "❌ Skipping ISO build"
fi
