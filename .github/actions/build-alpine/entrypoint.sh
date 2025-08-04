#!/bin/bash
set -e

# Input arguments
ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"

# Define working directories
ROOTDIR="$(pwd)/work/rootfs"
ISODIR="$(pwd)/work/isodir"
CACHEDIR="$(pwd)/work/cache"

mkdir -p "$ROOTDIR" "$ISODIR/boot" "$CACHEDIR"

# Function to download apk.static and unpack rootfs
download_and_unpack_rootfs() {
  echo "📥 Downloading apk.static and base packages..."

  cd "$CACHEDIR"

  # Download apk.static
  if [ ! -f "apk.static" ]; then
    wget "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/apk.static"
    chmod +x apk.static
  fi

  # Fetch base packages
  ./apk.static -X "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" \
               -U --allow-untrusted \
               --root "$ROOTDIR" --initdb add alpine-base bash e2fsprogs-extra util-linux

  echo "✅ Base system unpacked into $ROOTDIR"
}

# Step 1: prepare rootfs if not using cache or cache is empty
if [ "$USE_CACHE" != "true" ] || [ ! -d "$ROOTDIR/bin" ]; then
  rm -rf "$ROOTDIR"
  mkdir -p "$ROOTDIR"
  download_and_unpack_rootfs
else
  echo "📁 Using cached rootfs"
fi

# Step 2: minimal init script
echo "📝 Creating init script..."
cat << 'EOF' > "$ROOTDIR/init"
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
clear
echo "Welcome to Alpine Linux CLI Live!"
/bin/sh
EOF

chmod +x "$ROOTDIR/init"

# Step 3: build ISO only if requested
if [ "$BUILD_ISO" == "true" ]; then
  echo "📁 Building ISO structure..."

  mkdir -p "$ISODIR/boot" "$ISODIR/boot/grub"

  # Download vmlinuz and initramfs (mainline kernel)
  echo "📥 Downloading kernel and initrd from Alpine repo..."
  wget -q --show-progress "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/vmlinuz" -O "$ISODIR/boot/vmlinuz"
  wget -q --show-progress "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/initramfs" -O "$ISODIR/boot/initrd.gz"

  # Create grub.cfg
  echo "⚙️ Creating GRUB config..."
  cat <<EOF > "$ISODIR/boot/grub/grub.cfg"
set default=0
set timeout=5

menuentry "Alpine Linux CLI Live" {
    linux /boot/vmlinuz quiet
    initrd /boot/initrd.gz
}
EOF

  echo "📀 Creating ISO image..."
  xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "AlpineCLI" \
    -output "alpine-live-${ALPINE_VERSION}.iso" \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-catalog boot/grub/boot.cat \
    -boot-load-size 4 -boot-info-table \
    -grub2-boot-info \
    -grub2-mbr "$ISODIR/boot/grub/i386-pc/boot_hybrid.img" \
    "$ISODIR"

  echo "✅ ISO image created: alpine-live-${ALPINE_VERSION}.iso"
else
  echo "📦 ISO build skipped (BUILD_ISO=${BUILD_ISO})"
fi
