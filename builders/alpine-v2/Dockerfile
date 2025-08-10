# builders/alpine-v2/Dockerfile
FROM alpine:3.20

# Narzędzia potrzebne do mkimage.sh i tworzenia ISO
RUN apk add --no-cache \
    bash \
    alpine-sdk \
    squashfs-tools \
    xorriso \
    grub-efi \
    dosfstools \
    mtools \
    wget \
    syslinux \
    e2fsprogs \
    coreutils \
    findutils

WORKDIR /workspace

# Nie kopiujemy plików repo (workflow montuje workspace), ale chmod można wykonać w workflow.
