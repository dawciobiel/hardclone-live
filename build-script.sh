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
mkdir -p iso-mount iso-extract
sudo mount -o loop clonezilla-original.iso iso-mount
cp -r iso-mount/* iso-extract/
sudo umount iso-mount
rmdir iso-mount

cd iso-extract

# Extract squashfs filesystem
echo "Extracting filesystem..."
cd live
sudo unsquashfs filesystem.squashfs

# Clone your applications
echo "Downloading HardClone applications..."
cd squashfs-root

# Clone CLI application
git clone "$HARDCLONE_CLI_REPO" opt/hardclone-cli

# Clone GUI application  
git clone "$HARDCLONE_GUI_REPO" opt/hardclone-gui

# Make applications executable
sudo chmod +x opt/hardclone-cli/* 2>/dev/null || true
sudo chmod +x opt/hardclone-gui/* 2>/dev/null || true

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

# Add to PATH
echo 'export PATH="/opt/hardclone-cli:/opt/hardclone-gui:$PATH"' >> etc/bash.bashrc

# Create custom branding
echo "HardClone Live - Custom Clonezilla Distribution" > etc/motd

cd .. # back to live directory

# Repackage filesystem
echo "Repackaging filesystem..."
sudo rm filesystem.squashfs
sudo mksquashfs squashfs-root filesystem.squashfs -comp xz -Xbcj x86

# Clean up
sudo rm -rf squashfs-root

cd .. # back to iso-extract

# Update isolinux configuration (optional customization)
sed -i 's/Clonezilla live/HardClone Live/g' isolinux/isolinux.cfg 2>/dev/null || true
sed -i 's/Clonezilla/HardClone/g' boot/grub/grub.cfg 2>/dev/null || true

# Create new ISO
echo "Creating new ISO..."
sudo xorriso -as mkisofs \
    -r -V "HARDCLONE-LIVE" \
    -cache-inodes -J -l \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "../$ISO_NAME" .

cd ..

# Move ISO to workspace
mv "$ISO_NAME" "$WORK_DIR/"

# Clean up
rm -rf clonezilla-custom

echo "Build completed successfully!"
echo "ISO created: $ISO_NAME"
ls -lh "$WORK_DIR/$ISO_NAME"
