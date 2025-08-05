#!/bin/bash
set -e

# Input parameters
ALPINE_VERSION="$1"
USE_CACHE="$2"
BUILD_ISO="$3"
OUTPUT_ISO_PATH="$4"

echo "📦 Alpine version: $ALPINE_VERSION"
echo "🗃️ Use cache: $USE_CACHE"
echo "📀 Build ISO: $BUILD_ISO"
echo "🛠️ Output ISO path: $OUTPUT_ISO_PATH"

# Set up directory paths (relative to current script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
TOOLS_DIR="$SCRIPT_DIR/tools"
ISO_DIR="$SCRIPT_DIR/iso"
BUILD_DIR="$SCRIPT_DIR/build"
ISO_ROOT="$BUILD_DIR/iso_root"
CACHE_DIR="$BUILD_DIR/cache"

mkdir -p "$ISO_ROOT" "$CACHE_DIR" "$(dirname "$OUTPUT_ISO_PATH")"

echo "🔍 Checking required tools..."
for cmd in wget 7z xorriso tar bash proot curl mksquashfs; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required tool '$cmd' not found"
        exit 1
    fi
    echo "✅ $cmd found: $(command -v $cmd)"
done

echo "📥 Using local Syslinux BIOS boot files..."
cp "$TOOLS_DIR/isohdpfx.bin" "$CACHE_DIR/isohdpfx.bin"

echo "⬇️ Downloading and extracting Alpine minirootfs..."
ARCH="x86_64"
CACHE_FILE="$CACHE_DIR/alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"
if [ "$USE_CACHE" != "true" ] || [ ! -f "$CACHE_FILE" ]; then
    wget -O "$CACHE_FILE" "https://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION.0-$ARCH.tar.gz"
else
    echo "📦 Using cached minirootfs..."
fi

# Extract Alpine base system
tar -xzf "$CACHE_FILE" -C "$ISO_ROOT"

echo "🔧 Installing packages in chroot..."
# Bind mount /proc, /sys, /dev for chroot
mount --bind /proc "$ISO_ROOT/proc"
mount --bind /sys "$ISO_ROOT/sys"
mount --bind /dev "$ISO_ROOT/dev"

# Install packages
chroot "$ISO_ROOT" /bin/sh -c '
    echo "📦 Updating package repository..."
    apk update

    echo "🔧 Installing base system..."
    apk add alpine-base alpine-keys busybox busybox-initscripts openrc alpine-conf
    apk add linux-lts linux-firmware

    echo "🌐 Installing network tools..."
    apk add chrony openssh curl wget rsync

    echo "💻 Installing development tools..."
    apk add git python3 py3-pip
    apk add build-base gcc musl-dev
    apk add nodejs npm

    echo "🛠️ Installing CLI utilities..."
    apk add bash zsh fish
    apk add nano vim micro
    apk add htop btop iotop
    apk add tmux screen
    apk add tree file
    apk add grep sed awk
    apk add tar gzip bzip2 xz
    apk add jq yq

    echo "🐳 Installing Docker..."
    apk add docker docker-compose docker-cli-compose

    echo "📊 Installing system monitoring..."
    apk add neofetch
    apk add lshw pciutils usbutils
    apk add iftop nethogs

    echo "🔐 Installing security tools..."
    apk add sudo
    apk add gnupg

    echo "📁 Installing file utilities..."
    apk add mc
    apk add zip unzip
    apk add rsync

    echo "🔥 Installing additional development tools..."
    apk add go rust cargo
    apk add php php-cli composer
    apk add ruby ruby-dev

    echo "🌐 Installing more network tools..."
    apk add nmap masscan
    apk add wireshark-common tcpdump
    apk add bind-tools

    echo "📈 Installing monitoring and performance tools..."
    apk add stress-ng
    apk add sysstat
    apk add strace ltrace

    echo "⚙️ Setting up services..."
    rc-update add devfs sysinit
    rc-update add dmesg sysinit
    rc-update add mdev sysinit
    rc-update add hwdrivers sysinit
    rc-update add modloop sysinit
    rc-update add hwclock boot
    rc-update add modules boot
    rc-update add sysctl boot
    rc-update add hostname boot
    rc-update add bootmisc boot
    rc-update add syslog boot
    rc-update add networking boot
    rc-update add local default
    rc-update add chronyd default
    rc-update add sshd default
    rc-update add docker default

    echo "👤 Setting up users..."
    # Root password: alpine
    echo "root:alpine" | chpasswd

    # Add liveuser to groups
    addgroup liveuser wheel
    addgroup liveuser docker

    # Configure sudo
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
'

# Cleanup mounts
umount "$ISO_ROOT/dev" || true
umount "$ISO_ROOT/sys" || true
umount "$ISO_ROOT/proc" || true

echo "🏗️ Creating initramfs..."
chroot "$ISO_ROOT" /bin/sh -c "
    mkinitfs -o /boot/initramfs-lts /usr/share/kernel/lts/kernel.release
"

# Copy kernel and initramfs to boot directory
mkdir -p "$ISO_ROOT/boot"
cp "$ISO_ROOT/boot/vmlinuz-lts" "$ISO_ROOT/boot/" 2>/dev/null || true
cp "$ISO_ROOT/boot/initramfs-lts" "$ISO_ROOT/boot/" 2>/dev/null || true

echo "⚙️ Applying configuration..."
cp -rv "$CONFIG_DIR/"* "$ISO_ROOT/"

echo "🔧 Customizing ISO root..."
chmod +x "$ISO_ROOT/welcome.sh"

if [ "$BUILD_ISO" = "true" ]; then
    echo "📀 Creating ISO image..."

    BOOT_IMAGE="$CACHE_DIR/isohdpfx.bin"
    if [ ! -f "$BOOT_IMAGE" ]; then
        echo "❌ Missing isohdpfx.bin in $CACHE_DIR"
        exit 1
    fi

    SYSROOT="$ISO_ROOT/boot/syslinux"
    mkdir -p "$SYSROOT"

    # Copy syslinux boot files
    cp "$ISO_DIR/boot/isolinux/isolinux.bin" "$SYSROOT/"
    cp "$ISO_DIR/boot/isolinux/ldlinux.c32" "$SYSROOT/"
    cp "$ISO_DIR/boot/isolinux/memdisk" "$SYSROOT/"
    cp "$ISO_DIR/boot/isolinux/menu.c32" "$SYSROOT/"
    cp "$ISO_DIR/boot/isolinux/vesamenu.c32" "$SYSROOT/"

    echo "Creating ISO file at: $OUTPUT_ISO_PATH"

    xorriso -as mkisofs \
        -o "$OUTPUT_ISO_PATH" \
        -isohybrid-mbr "$BOOT_IMAGE" \
        -c boot/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
        -V "ALPINE_LIVE" \
        "$ISO_ROOT"

    echo "✅ ISO image created: $OUTPUT_ISO_PATH"
fi
