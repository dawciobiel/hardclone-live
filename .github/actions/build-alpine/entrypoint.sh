#!/bin/bash
set -e

ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Using Alpine version: $ALPINE_VERSION"
echo "🗂️ Use cache: $USE_CACHE"
echo "💿 Build ISO: $BUILD_ISO"

WORKDIR="$(pwd)/alpine-${ALPINE_VERSION}"
CACHEDIR="$WORKDIR/cache"
ISODIR="$WORKDIR/iso"
ROOTFS_DIR="$WORKDIR/rootfs"
OUT_ISO="alpine-${ALPINE_VERSION}-live.iso"
MINIROOTFS_TAR="alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${MINIROOTFS_TAR}"

mkdir -p "$CACHEDIR" "$ISODIR" "$ROOTFS_DIR"

cd "$CACHEDIR"

# Step 1: Download minirootfs if needed
if [[ "$USE_CACHE" != "true" || ! -f "$MINIROOTFS_TAR" ]]; then
  echo "⬇️ Downloading Alpine Minirootfs..."
  wget -q --show-progress "$MINIROOTFS_URL"
else
  echo "✅ Using cached $MINIROOTFS_TAR"
fi

# Step 2: Extract rootfs
echo "📂 Extracting minirootfs..."
rm -rf "$ROOTFS_DIR"/*
tar -xzf "$MINIROOTFS_TAR" -C "$ROOTFS_DIR"

# Step 3: Setup base system in proot
echo "🔧 Installing extra packages in proot..."
mkdir -p "$ROOTFS_DIR/proot-tmp"
proot -R "$ROOTFS_DIR" /bin/sh -c "
  apk update &&
  apk add bash coreutils util-linux e2fsprogs dosfstools syslinux xorriso \
          parted python3 nano mc htop curl wget ca-certificates
"

# Step 4: Create init script
echo "📝 Creating init script..."
cat > "$ROOTFS_DIR/init" <<'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
clear
echo "Welcome to Alpine Linux Live CLI!"
/bin/sh
EOF

chmod +x "$ROOTFS_DIR/init"

# Step 5: Prepare ISO structure
echo "📁 Building ISO structure..."
mkdir -p "$ISODIR"/{boot/grub,boot/syslinux}
cp -a "$ROOTFS_DIR"/* "$ISODIR"

# Step 6: Create isolinux.cfg
cat > "$ISODIR/boot/syslinux/isolinux.cfg" <<EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT alpine

LABEL alpine
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.gz init=/init
EOF

# Step 7: Download prebuilt kernel and initrd from Alpine
echo "📥 Downloading kernel and initrd from Alpine repo..."

KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64"
wget -q --show-progress "$KERNEL_URL"/vmlinuz-lts -O "$ISODIR/boot/vmlinuz"
wget -q --show-progress "$KERNEL_URL"/initramfs-lts -O "$ISODIR/boot/initrd.gz"


# Step 8: Copy syslinux binaries
cp /usr/lib/ISOLINUX/isolinux.bin "$ISODIR/boot/syslinux/"
cp /usr/lib/syslinux/modules/bios/* "$ISODIR/boot/syslinux/" || true

# Step 9: Build final ISO
if [[ "$BUILD_ISO" == "true" ]]; then
  echo "💿 Building final ISO image..."
  xorriso -as mkisofs \
    -o "$OUT_ISO" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -V "AlpineLive" \
    "$ISODIR"

  echo "✅ ISO created: $OUT_ISO"
else
  echo "🛑 ISO build skipped (BUILD_ISO=$BUILD_ISO)"
fi
