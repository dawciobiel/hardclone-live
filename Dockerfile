FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    squashfs-tools \
    xorriso \
    p7zip-full \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy build script
COPY build-script.sh /build/
RUN chmod +x build-script.sh

# Set entrypoint
ENTRYPOINT ["./build-script.sh"]
