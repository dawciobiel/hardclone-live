#!/bin/bash

set -e

# Configuration - get latest version
echo "Getting latest Clonezilla version..."
CLONEZILLA_VERSION=$(curl -s "https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/" | grep -o 'href="/projects/clonezilla/files/clonezilla_live_stable/[0-9][^/]*' | head -1 | cut -d'/' -f6)
echo "Latest version: $CLONEZILLA_VERSION"
CLONEZILLA_URL="https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/${CLONEZILLA_VERSION}/clonezilla-live-${CLONEZILLA_VERSION}-amd64.iso/download"
WORK_DIR="/workspace"
ISO_NAME="hardclone-live-$(date +%Y%m%d).iso"

# CLI and GUI repository URLs
HARDCLONE_CLI_REPO="https://github.com/dawciobiel/hardclone-cli.git"
HARDCLONE_GUI_REPO="https://github.com/dawciobiel/hardclone-gui.git"

echo "Building HardClone Live ISO..."

cd "$WORK_DIR"

# Create working directories
mkdir -p clonezilla-custom
cd clonezilla-custom

# Download Clonezilla ISO
echo "Downloading Clonezilla ISO..."
wget -O clonezilla-original.iso "$CLONEZILLA_URL"

# Mount and extract ISO
echo "Extracting Clonezilla ISO..."
mkdir -p iso-extract
7z x clonezilla-original.iso -oiso-extract

cd iso-extract

# Extract squashfs filesystem
echo "Extracting filesystem..."
cd live
unsquashfs filesystem.squashfs

# Clone your applications
echo "Downloading HardClone applications..."
cd squashfs-root

# Clone CLI application
git clone "$HARDCLONE_CLI_REPO" opt/hardclone-cli

# Clone GUI application  
git clone "$HARDCLONE_GUI_REPO" opt/hardclone-gui

# Make applications executable
chmod +x opt/hardclone-cli/* 2>/dev/null || true
chmod +x opt/hardclone-gui/* 2>/dev/null || true

# Install additional packages
echo "Preparing additional packages..."

# Debug FIRST
echo "=== EARLY DEBUG ==="
echo "Current directory: $(pwd)"

# We're already inside squashfs-root, so use relative paths
# Create necessary directories
echo "Creating directories..."
mkdir -p usr/local/bin || { echo "Failed to create usr/local/bin"; exit 1; }
mkdir -p var/log || { echo "Failed to create var/log"; exit 1; }
echo "Directories created successfully"

# Create installation script that will run on boot
echo "Creating first-boot-setup.sh..."
cat > usr/local/bin/first-boot-setup.sh << 'FBEOF'
#!/bin/bash
# First boot setup script
if [ ! -f /var/log/hardclone-setup-done ]; then
    echo "HardClone: Installing additional packages..."
    apt update
    apt install -y python3-pip python3-venv python3-dialog git xxd fish
    
    # Mark as done
    touch /var/log/hardclone-setup-done
    echo "HardClone: Setup completed"
fi
FBEOF

if [ $? -eq 0 ]; then
    chmod +x usr/local/bin/first-boot-setup.sh
    echo "first-boot-setup.sh created successfully"
else
    echo "ERROR: Failed to create first-boot-setup.sh"
    exit 1
fi

echo "DEBUG: About to create desktop shortcuts"

# Configure network to start automatically
echo "Configuring network..."
# Create network startup script
cat > usr/local/bin/network-setup.sh << 'NETEOF'
#!/bin/bash
# Auto-start network and update packages
sleep 5
dhclient eth0 2>/dev/null || dhclient 2>/dev/null &
sleep 10
apt update &
NETEOF
chmod +x usr/local/bin/network-setup.sh

# Add to startup (multiple methods for compatibility)
echo "/usr/local/bin/network-setup.sh &" >> etc/rc.local
# Also add to bashrc for interactive sessions
echo "/usr/local/bin/network-setup.sh &" >> etc/bash.bashrc

# Create desktop shortcuts (optional)
mkdir -p home/user/Desktop
cat > home/user/Desktop/HardClone-CLI.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=HardClone CLI
Comment=Command line backup tool
Exec=/opt/hardclone-cli/hardclone
Icon=utilities-terminal
Terminal=true
Categories=System;
EOF

cat > home/user/Desktop/HardClone-GUI.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=HardClone GUI
Comment=Graphical backup tool
Exec=/opt/hardclone-gui/hardclone-gui
Icon=drive-harddisk
Terminal=false
Categories=System;
EOF

chmod +x home/user/Desktop/*.desktop
echo "DEBUG: Desktop shortcuts created"

# Add to PATH
echo 'export PATH="/opt/hardclone-cli:/opt/hardclone-gui:$PATH"' >> etc/bash.bashrc
echo "DEBUG: Added to PATH"

# Create custom branding
echo "HardClone Live - Custom Clonezilla Distribution" > etc/motd
echo "DEBUG: Custom branding added"

cd .. # back to live directory
echo "DEBUG: Changed back to live directory: $(pwd)"

# Repackage filesystem
echo "Repackaging filesystem..."
rm filesystem.squashfs
mksquashfs squashfs-root filesystem.squashfs -comp xz -Xbcj x86

# Clean up
rm -rf squashfs-root

cd .. # back to iso-extract

# Update isolinux configuration (optional customization)
sed -i 's/Clonezilla live/HardClone Live/g' isolinux/isolinux.cfg 2>/dev/null || true
sed -i 's/Clonezilla/HardClone/g' boot/grub/grub.cfg 2>/dev/null || true

# Check boot file locations
echo "Checking boot files..."
find . -name "isolinux.bin" -type f
find . -name "efi.img" -type f
find . -name "*.efi" -type f

# Detect correct paths
ISOLINUX_BIN=$(find . -name "isolinux.bin" -type f | head -1)
EFI_IMG=$(find . -name "efi.img" -o -name "*.efi" | head -1)

echo "Found isolinux.bin at: $ISOLINUX_BIN"
echo "Found EFI image at: $EFI_IMG"

# Create new ISO with detected paths
echo "Creating new ISO..."
if [ -n "$ISOLINUX_BIN" ] && [ -n "$EFI_IMG" ]; then
    # Get directory of isolinux.bin for boot catalog
    ISOLINUX_DIR=$(dirname "${ISOLINUX_BIN#./}")
    
    xorriso -as mkisofs \
        -r -V "HARDCLONE-LIVE" \
        -J -l \
        -b "${ISOLINUX_BIN#./}" \
        -c "${ISOLINUX_DIR}/boot.cat" \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e "${EFI_IMG#./}" \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -o "../$ISO_NAME" .
else
    echo "Boot files not found, creating basic ISO..."
    xorriso -as mkisofs \
        -r -V "HARDCLONE-LIVE" \
        -J -l \
        -o "../$ISO_NAME" .
fi

cd ..

# Move ISO to workspace
mv "$ISO_NAME" "$WORK_DIR/"

# Clean up
rm -rf clonezilla-custom

echo "Build completed successfully!"
echo "ISO created: $ISO_NAME"
ls -lh "$WORK_DIR/$ISO_NAME"
