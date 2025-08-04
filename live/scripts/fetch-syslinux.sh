#!/bin/bash
# Downloads necessary Syslinux files for BIOS boot (isolinux.bin and ldlinux.c32)

set -e

TARGET_DIR="live/boot/syslinux"
mkdir -p "$TARGET_DIR"

# Download isolinux.bin and ldlinux.c32 from Arch repo (they are independent of distro)
wget -O "$TARGET_DIR/isolinux.bin" https://repo.archlinux.org/other/syslinux/isolinux.bin
wget -O "$TARGET_DIR/ldlinux.c32" https://repo.archlinux.org/other/syslinux/ldlinux.c32

echo "✅ Syslinux files downloaded to $TARGET_DIR"

