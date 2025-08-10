#!/bin/sh
set -e

ISO_ROOT="./iso-root"
APK_VER="v3.20"

echo "[1/6] Przygotowanie struktury rootfs..."
mkdir -p "$ISO_ROOT/etc/apk/keys"
mkdir -p "$ISO_ROOT/etc/apk"

echo "[2/6] Kopiowanie kluczy Alpine..."
cp -r /etc/apk/keys/* "$ISO_ROOT/etc/apk/keys/"

echo "[3/6] Konfiguracja repozytoriów..."
cat > "$ISO_ROOT/etc/apk/repositories" <<EOF
https://dl-cdn.alpinelinux.org/alpine/${APK_VER}/main
https://dl-cdn.alpinelinux.org/alpine/${APK_VER}/community
EOF

echo "[4/6] Instalacja systemu bazowego i pakietów..."
apk --root "$ISO_ROOT" --initdb add \
    alpine-base \
    python3 \
    py3-pip \
    docker \
    openrc \
    grub \
    grub-efi \
    syslinux \
    mtools

echo "[5/6] Dodawanie aplikacji..."
mkdir -p "$ISO_ROOT/opt/myapp"
cp /workspace/builders/alpine-v2/app.py "$ISO_ROOT/opt/myapp/"

cat > "$ISO_ROOT/usr/local/bin/start-myapp.sh" <<'EOF'
#!/bin/sh
echo "Uruchamiam aplikację..."
python3 /opt/myapp/app.py
EOF
chmod +x "$ISO_ROOT/usr/local/bin/start-myapp.sh"

# Dodaj do OpenRC, aby uruchamiał się po starcie
cat > "$ISO_ROOT/etc/local.d/start-myapp.start" <<'EOF'
#!/bin/sh
/usr/local/bin/start-myapp.sh
EOF
chmod +x "$ISO_ROOT/etc/local.d/start-myapp.start"

echo "[6/6] Tworzenie obrazu ISO..."
mkdir -p iso-boot/boot/grub

# Konfiguracja GRUB dla BIOS + UEFI
cat > iso-boot/boot/grub/grub.cfg <<'EOF'
set timeout=5
set default=0

menuentry "Alpine Live with MyApp" {
    linux /boot/vmlinuz-lts root=/dev/ram0 alpine_dev=UUID=xxxxxxx modules=loop,squashfs,sd-mod,usb-storage quiet
    initrd /boot/initramfs-lts
}
EOF

# Kopiowanie kernela i initramfs
cp "$ISO_ROOT"/boot/vmlinuz-lts iso-boot/boot/
cp "$ISO_ROOT"/boot/initramfs-lts iso-boot/boot/

# Tworzenie ISO
grub-mkrescue -o alpine-live.iso iso-boot

echo "Gotowe! Obraz zapisany jako alpine-live.iso"
