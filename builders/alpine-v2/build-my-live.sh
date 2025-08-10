#!/bin/bash
set -e

# Ustawienia
PROFILE_NAME="custom-alpine"
ARTIFACTS_DIR="/workspace/artifacts/alpine"

# Tworzenie katalogów
mkdir -p "$ARTIFACTS_DIR"
mkdir -p "./iso-root/root"

# Kopiowanie aplikacji
cp /workspace/builders/alpine-v2/app.py ./iso-root/root/

# Instalacja minimalnego Alpine w katalogu iso-root
apk --root ./iso-root --initdb add alpine-base python3 py3-pip

# Dodanie GRUB i ustawień bootowania
mkdir -p ./iso-root/boot/grub
cat > ./iso-root/boot/grub/grub.cfg <<EOF
set default=0
set timeout=5

menuentry "Custom Alpine Live" {
    linux /boot/vmlinuz root=/dev/ram0 alpine_dev=LABEL=ALPINE_LIVE modules=loop,squashfs,sd-mod,usb-storage quiet
    initrd /boot/initramfs
}
EOF

# Pobranie jądra Alpine
wget -O ./iso-root/boot/vmlinuz https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/netboot/vmlinuz-lts
wget -O ./iso-root/boot/initramfs https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/netboot/initramfs-lts

# Utworzenie pliku ISO
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "ALPINE_LIVE" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -output "$ARTIFACTS_DIR/${PROFILE_NAME}.iso" \
  ./iso-root

echo "ISO gotowe: $ARTIFACTS_DIR/${PROFILE_NAME}.iso"
