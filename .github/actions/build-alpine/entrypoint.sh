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

echo "⚙️ Applying configuration..."
cp -rv "$CONFIG_DIR/"* "$ISO_ROOT/"

echo "🔧 Customizing ISO root..."
chmod +x "$ISO_ROOT/welcome.sh"

echo "🔧 Installing packages using proot..."

# Use proot instead of chroot (doesn't require root privileges)
proot -R "$ISO_ROOT" /bin/sh -c '
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
    addgroup liveuser wheel 2>/dev/null || true
    addgroup liveuser docker 2>/dev/null || true
    
    # Configure sudo
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
'

echo "🏗️ Creating initramfs..."
proot -R "$ISO_ROOT" /bin/sh -c '
    if [ -f /usr/share/kernel/lts/kernel.release ]; then
        mkinitfs -o /boot/initramfs-lts $(cat /usr/share/kernel/lts/kernel.release)
    else
        echo "⚠️ Kernel release file not found, trying alternative method..."
        KERNEL_VERSION=$(ls /lib/modules/ | head -n1)
        if [ -n "$KERNEL_VERSION" ]; then
            mkinitfs -o /boot/initramfs-lts $KERNEL_VERSION
        else
            echo "❌ Could not determine kernel version"
        fi
    fi
'

# Create enhanced live boot script
cat > "$ISO_ROOT/etc/local.d/live-boot.start" << 'EOF'
#!/bin/sh
echo "🚀 Setting up Alpine Live CLI environment..."

# Mount tmpfs for writable home
if ! mountpoint -q /home; then
    mount -t tmpfs -o size=512M tmpfs /home
fi

# Create live user home
mkdir -p /home/liveuser
chown liveuser:liveuser /home/liveuser 2>/dev/null || true

# Create welcome script
cat > /home/liveuser/.bashrc << 'BASHRC_EOF'
export PS1='\[\033[01;32m\]liveuser@alpine-live\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "🐧 Welcome to Alpine Linux Live CLI!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Available tools:"
echo "  • Development: git, python3, nodejs, docker, go, rust"  
echo "  • Editors: nano, vim, micro"
echo "  • Monitoring: htop, btop, iotop"
echo "  • Network: wget, curl, ssh, nmap"
echo "  • Security: wireshark, tcpdump"
echo ""
echo "Users:"
echo "  • root (password: alpine)"
echo "  • liveuser (password: live, sudo access)"
echo ""
echo "Services:"
echo "  • SSH server running on port 22"
echo "  • Docker daemon available"
echo ""
echo "Type 'neofetch' to see system info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BASHRC_EOF

chown liveuser:liveuser /home/liveuser/.bashrc 2>/dev/null || true

# Start Docker daemon if available
if command -v dockerd >/dev/null 2>&1; then
    if ! pgrep dockerd > /dev/null; then
        dockerd &
    fi
fi

echo "✅ Live environment setup complete!"
EOF

chmod +x "$ISO_ROOT/etc/local.d/live-boot.start"

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

    # Copy kernel and initramfs to ISO boot directory
    if [ -f "$ISO_ROOT/boot/vmlinuz-lts" ]; then
        cp "$ISO_ROOT/boot/vmlinuz-lts" "$ISO_ROOT/boot/"
        echo "✅ Kernel copied"
    else
        echo "⚠️ Kernel not found at expected location"
    fi
    
    if [ -f "$ISO_ROOT/boot/initramfs-lts" ]; then
        cp "$ISO_ROOT/boot/initramfs-lts" "$ISO_ROOT/boot/"
        echo "✅ Initramfs copied"
    else
        echo "⚠️ Initramfs not found at expected location"
    fi

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
    
    # Show ISO size
    if [ -f "$OUTPUT_ISO_PATH" ]; then
        ISO_SIZE=$(du -h "$OUTPUT_ISO_PATH" | cut -f1)
        echo "📊 ISO size: $ISO_SIZE"
    fi
fi
