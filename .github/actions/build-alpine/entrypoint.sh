#!/bin/bash
set -e

ALPINE_VERSION="${1:-3.18}"
USE_CACHE="${2:-true}"
BUILD_ISO="${3:-true}"

echo "📦 Alpine version: ${ALPINE_VERSION}"
echo "🗃️ Use cache: ${USE_CACHE}"
echo "📀 Build ISO: ${BUILD_ISO}"

echo "🔍 Checking required tools..."

check_tool() {
    local tool="$1"
    local version_cmd="$2"
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ $tool not found!"
        exit 1
    else
        local version_output
        version_output=$(eval "$version_cmd" 2>/dev/null || echo "OK")
        echo "✅ $tool found: $version_output"
    fi
}

check_tool wget "wget --version | head -n1"
check_tool 7z "7z | head -n2 | tail -n1"
check_tool xorriso "xorriso -version | head -n1"
check_tool tar "tar --version | head -n1"
check_tool bash "bash --version | head -n1"

WORKDIR="$(pwd)"
OUTDIR="${WORKDIR}/alpine-${ALPINE_VERSION}"
CACHEDIR="${WORKDIR}/.cache"
ROOTFS="${OUTDIR}/rootfs"
ISO_DIR="${OUTDIR}/iso"
ISO_FILE="${WORKDIR}/alpine-${ALPINE_VERSION}-custom.iso"
MIRROR="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64"

mkdir -p "${ROOTFS}"
mkdir -p "${CACHEDIR}"

echo "📥 Downloading apk.static and base packages..."

APK_TOOLS_URL="${MIRROR}/apk-tools-static-2.12.10-r1.apk"
BASE_TAR_URL="${MIRROR}/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

echo "🔗 ${APK_TOOLS_URL}"
echo "🔗 ${BASE_TAR_URL}"

cd "${CACHEDIR}"
wget -N "${APK_TOOLS_URL}" || { echo "❌ Failed to download apk-tools"; exit 1; }
wget -N "${BASE_TAR_URL}" || { echo "❌ Failed to download base rootfs"; exit 1; }

cd "${ROOTFS}"
tar -xzf "${CACHEDIR}/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

cd "${WORKDIR}"
echo "✅ Root filesystem prepared at: ${ROOTFS}"

if [ "${BUILD_ISO}" = "true" ]; then
    echo "🚧 Preparing ISO structure..."

    mkdir -p "${ISO_DIR}/boot"

    echo "📥 Downloading kernel and initrd..."
    wget -N "${MIRROR}/vmlinuz" -O "${ISO_DIR}/boot/vmlinuz" || echo "⚠️ Warning: Kernel file not found at ${MIRROR}/vmlinuz"
    wget -N "${MIRROR}/initramfs" -O "${ISO_DIR}/boot/initramfs" || echo "⚠️ Warning: Initrd file not found at ${MIRROR}/initramfs"

    echo "🛠️ Creating ISO image..."
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "ALPINE_LIVE" \
        -output "${ISO_FILE}" \
        -eltorito-boot boot/vmlinuz \
        -eltorito-catalog boot/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/initramfs \
        -no-emul-boot \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c boot/boot.cat \
        -b boot/syslinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "${ISO_DIR}" || echo "⚠️ Failed to create ISO image!"

    echo "✅ ISO image created at: ${ISO_FILE}"
fi
