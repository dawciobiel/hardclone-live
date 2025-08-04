#!/bin/bash
set -euo pipefail

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

WORKDIR="$(pwd)/work/v${ALPINE_VERSION}"
CACHEDIR="$WORKDIR/cache"
ROOTFS="$WORKDIR/rootfs"
ISODIR="$WORKDIR/isodir"
OUT_ISO="alpine-${ALPINE_VERSION}-live.iso"

mkdir -p "$CACHEDIR" "$ROOTFS" "$ISODIR/boot/grub"

MINIROOTFS_TAR="alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${MINIROOTFS_TAR}"

cd "$CACHEDIR"

# Download Alpine minirootfs
if [[ "$USE_CACHE" != "true" || ! -f "$MINIROOTFS_TAR" ]]; then
  echo "⬇️ Downloading Alpine minirootfs..."
  wget -q --show-progress "$MINIROOTFS_URL"
else
  echo "✅ Using cached minirootfs"
fi

# Extract root filesystem
echo "📂 Extracting rootfs..."
rm -rf "$ROOTFS"/*
tar -xzf "$MINIROOTFS_TAR" -C "$ROOTFS"
echo "✅ Rootfs ready at: $ROOTFS"

# Install extra packages using proot
echo "🔧 Installing CLI packages..."
proot -R "$ROOTFS" apk update
proot -R "$ROOTFS" apk add --no-cache bash util-linux e2fsprogs parted mc python3 sudo

# Create minimalist init
cat > "$ROOTFS/init" <<'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
clear
echo "Alpine Live CLI: logged in as root"
export PS1="alpine~# "
/bin/bash
EOF

chmod +x "$ROOTFS/init"

if [[ "$BUILD_ISO" == "true" ]]; then
  echo "🚧 Preparing ISO structure..."

  cp -a "$ROOTFS"/* "$ISODIR/"
  
  echo "📥 Downloading kernel and initramfs..."
  wget -q --show-progress "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/vmlinuz" -O "$ISODIR/boot/vmlinuz"
  wget -q --show-progress "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/initramfs" -O "$ISODIR/boot/initrd"

  echo "⚙️ Creating GRUB config..."
  cat > "$ISODIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0
menuentry "Alpine Live CLI $ALPINE_VERSION" {
  linux /boot/vmlinuz quiet
  initrd /boot/initrd
}
EOF

  echo "💿 Building ISO..."
  xorriso -as mkisofs \
    -output "$OUT_ISO" \
    -volid ALPINE_LIVE_CLI \
    -boot-grub2 \
    "$ISODIR"

  echo "✅ ISO created: $OUT_ISO"
else
  echo "🛑 Build ISO skipped"
fi
