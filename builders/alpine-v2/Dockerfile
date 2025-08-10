FROM alpine:3.20

# Install build dependencies
RUN apk add --no-cache \
    bash \
    alpine-sdk \
    squashfs-tools \
    xorriso \
    grub-efi \
    dosfstools \
    mtools \
    wget \
    python3 \
    py3-pip

WORKDIR /workspace

# Copy build script and app
COPY build-my-live.sh /workspace/build-my-live.sh
COPY app.py /workspace/app.py

RUN chmod +x /workspace/build-my-live.sh
