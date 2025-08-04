#!/bin/bash
set -euo pipefail

ALPINE_VERSION="${1:-3.19}"
UPLOAD_ARTIFACTS="${2:-false}"
USE_CACHE="${3:-true}"

MINIROOTFS="alpine-minirootfs.tar.gz"
WORKDIR="alpine-rootfs"
OUTDIR="out"
ISONAME="alpine-${ALPINE_VERSION}-live.iso"

mkdir -p "$WORKDIR" "$OUTDIR"

# Download Alpine Minirootfs if needed
if [[ "$USE_CACHE" != "true" || ! -f "$MINIROOTFS" ]]; then
  echo "Downloading Alpine minirootfs..."
  curl -LO "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
  mv "alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" "$MINIROOTFS"
else
  echo "Using cached minirootfs."
fi

# Extract rootfs
echo "Extracting minirootfs..."
rm -rf "$WORKDIR"/*
tar -xzf "$MINIROOTFS" -C "$WORKDIR"

# Customizations (add packages etc.)
echo "Installing extra packages..."
chroot "$WORKDIR" /bin/sh -c "
  apk update
  apk add bash nano parted mc python3
  echo 'export PS1=\"[Alpine Live \w]# \"' >> /etc/profile
"

# Create SquashFS root filesystem
echo "Creating SquashFS filesystem..."
mksquashfs "$WORKDIR" "$OUTDIR/rootfs.sqsh" -comp zstd -e boot

# Create ISO with isolinux and EFI boot support
echo "Creating Alpine Live ISO..."
xorriso -as mkisofs -o "$OUTDIR/$ISONAME" \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c boot/boot.cat \
  -b isolinux/isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/efiboot.img -no-emul-boot \
  "$WORKDIR"

# Generate checksums
echo "Generating checksums..."
cd "$OUTDIR"
sha256sum "$ISONAME" > "${ISONAME}.sha256"
md5sum "$ISONAME" > "${ISONAME}.md5"
cd ..

# Optional: artifact handling if needed
if [[ "$UPLOAD_ARTIFACTS" == "true" ]]; then
  echo "::notice::Artifacts ready in $OUTDIR"
fi

echo "✅ Build complete: $OUTDIR/$ISONAME"

