#!/bin/sh
set -euo pipefail

WORKDIR=/workspace
ISO_ROOT="$WORKDIR/iso-root"
ISO_BUILD="$WORKDIR/iso-build"
ARTIFACTS_DIR="$WORKDIR/artifacts/alpine"
APP_DIR="$ISO_ROOT/opt/myapp"

ALPINE_VERSION="v3.20"
ARCH="x86_64"

echo "[1] Przygotowanie katalogów..."
rm -rf "$ISO_ROOT" "$ISO_BUILD" "$ARTIFACTS_DIR"
mkdir -p "$ISO_ROOT" "$ISO_BUILD/iso/boot/grub" "$ARTIFACTS_DIR" "$APP_DIR"

echo "[2] Bootstrap Alpine rootfs..."
mkdir -p "$ISO_ROOT/etc/apk/keys"
cp -r /etc/apk/keys/* "$ISO_ROOT/etc/apk/keys"

cat > "$ISO_ROOT/etc/apk/repositories" <<EOF
https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/main
https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/community
EOF

apk --root "$ISO_ROOT" --initdb add alpine-base python3 py3-pip openrc bash linux-virt linux-virt-initramfs

echo "[3] Kopiowanie aplikacji..."
cp "$WORKDIR/builders/alpine-v2/app.py" "$APP_DIR"

echo "[4] Tworzenie skryptu startowego aplikacji..."
cat > "$ISO_ROOT/usr/local/bin/start-myapp.sh" <<'EOF'
#!/bin/sh
echo "Uruchamiam aplikację Python..."
python3 /opt/myapp/app.py
EOF
chmod +x "$ISO_ROOT/usr/local/bin/start-myapp.sh"

echo "[5] Konfiguracja autostartu aplikacji..."
mkdir -p "$ISO_ROOT/etc/local.d"
cat > "$ISO_ROOT/etc/local.d/start-myapp.start" <<'EOF'
#!/bin/sh
/usr/local/bin/start-myapp.sh
EOF
chmod +x "$ISO_ROOT/etc/local.d/start-myapp.start"

ln -sf /etc/init.d/local "$ISO_ROOT/etc/runlevels/default/local"

echo "[6] Kopiowanie kernela i initramfs z rootfs..."
cp "$ISO_ROOT/boot/vmlinuz-virt" "$ISO_BUILD/iso/boot/vmlinuz"
cp "$ISO_ROOT/boot/initramfs-virt" "$ISO_BUILD/iso/boot/initramfs"

echo "[7] Tworzenie obrazu squashfs z rootfs..."
mksquashfs "$ISO_ROOT" "$ISO_BUILD/iso/rootfs.squashfs" -comp xz -no-progress -noappend

echo "[8] Tworzenie pliku grub.cfg..."
cat > "$ISO_BUILD/iso/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry "Alpine Linux Live with Python App" {
    linux /boot/vmlinuz root=live:CDLABEL=ALPINE_ISO modules=loop,squashfs,sd-mod,usb-storage quiet
    initrd /boot/initramfs
}
EOF

echo "[9] Instalacja GRUB BIOS..."
grub-install --target=i386-pc --boot-directory="$ISO_BUILD/iso/boot" --modules="part_msdos part_gpt" --recheck --force /dev/null

echo "[10] Instalacja GRUB UEFI..."
mkdir -p "$ISO_BUILD/iso/EFI/BOOT"
grub-install --target=x86_64-efi --efi-directory="$ISO_BUILD/iso" --boot-directory="$ISO_BUILD/iso/boot" --removable --recheck

echo "[11] Tworzenie pliku isolinux.cfg dla BIOS..."
mkdir -p "$ISO_BUILD/iso/boot/syslinux"
cat > "$ISO_BUILD/iso/boot/syslinux/isolinux.cfg" <<EOF
UI menu.c32
PROMPT 0
MENU TITLE Alpine Live Boot Menu
TIMEOUT 50
DEFAULT linux

LABEL linux
    KERNEL /boot/vmlinuz
    APPEND root=live:CDLABEL=ALPINE_ISO modules=loop,squashfs,sd-mod,usb-storage quiet
    INITRD /boot/initramfs
EOF

echo "[12] Tworzenie ISO..."
xorriso -as mkisofs \
  -iso-level 3 \
  -o "$ARTIFACTS_DIR/alpine-live.iso" \
  -full-iso9660-filenames \
  -volid "ALPINE_ISO" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
  -eltorito-catalog boot/grub/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --eltorito-alt-boot \
  -e boot/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$ISO_BUILD/iso"

echo "Gotowe! ISO zapisane w $ARTIFACTS_DIR/alpine-live.iso"
