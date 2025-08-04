#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

echo "🔍 Checking required tools..."

# Lista wymaganych programów
REQUIRED_CMDS=("wget" "7z" "tar" "bash")
MISSING_CMDS=()

# Sprawdzamy obecność wymaganych narzędzi
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING_CMDS+=("$cmd")
  else
    VERSION=$($cmd --version 2>&1 | head -n1)
    echo "✅ $cmd found: $VERSION"
  fi
done

# Sprawdzamy, czy jest mkisofs lub xorriso do tworzenia ISO
if command -v mkisofs >/dev/null 2>&1; then
  ISO_MAKER="mkisofs"
elif command -v xorriso >/dev/null 2>&1; then
  ISO_MAKER="xorriso"
else
  MISSING_CMDS+=("mkisofs or xorriso")
fi

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
  echo "❌ Missing required tools: ${MISSING_CMDS[*]}"
  echo "❌ One or more required tools are missing. Exiting."
  exit 1
fi

echo "✅ ISO maker found: $ISO_MAKER"

WORKDIR="$(pwd)/alpine-${ALPINE_VERSION}"
CACHEDIR="$WORKDIR/cache"
ISODIR="$WORKDIR/iso"
ROOTFS_DIR="$WORKDIR/rootfs"

MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"

mkdir -p "$CACHEDIR" "$ISODIR" "$ROOTFS_DIR"

cd "$CACHEDIR"

echo "📥 Downloading Alpine minirootfs..."
wget -N "$MINIROOTFS_URL"

echo "✅ Download completed. Extracting..."

tar -xzf "alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" -C "$ROOTFS_DIR"

echo "✅ Root filesystem prepared at: $ROOTFS_DIR"

# Dalsza logika budowania ISO - jeśli build-iso jest true
if [ "$BUILD_ISO" == "true" ]; then
  echo "🚧 Preparing ISO structure..."

  # Przykładowa minimalna struktura do ISO
  mkdir -p "$ISODIR/boot"

  echo "📥 Downloading kernel and initrd..."

  # Pobierz kernel i initrd - przykładowe pliki (możesz je zmienić)
  KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/vmlinuz-lts"
  INITRD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/initramfs-lts"

  wget -N -P "$ISODIR/boot" "$KERNEL_URL" || {
    echo "⚠️ Warning: Kernel file not found at $KERNEL_URL"
  }
  wget -N -P "$ISODIR/boot" "$INITRD_URL" || {
    echo "⚠️ Warning: Initrd file not found at $INITRD_URL"
  }

  echo "🛠️ Creating ISO image..."

  ISO_NAME="alpine-${ALPINE_VERSION}-custom.iso"
  cd "$ISODIR"

  if [ "$ISO_MAKER" == "xorriso" ]; then
    xorriso -as mkisofs -o "../$ISO_NAME" -b boot/vmlinuz-lts -c boot/boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table .
  else
    mkisofs -o "../$ISO_NAME" -b boot/vmlinuz-lts -c boot/boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table .
  fi

  echo "✅ ISO image created at: $WORKDIR/$ISO_NAME"
fi
