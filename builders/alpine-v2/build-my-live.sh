#!/bin/bash
set -e

ALPINE_VERSION="v3.20"
ARCH="x86_64"
OUTDIR="artifacts/alpine"
APP_FILE="app.py"
PROFILE_NAME="my-python-live"

mkdir -p "$OUTDIR"

# Download mkimage.sh
if [ ! -f mkimage.sh ]; then
    wget https://gitlab.alpinelinux.org/alpine/mkimage/-/raw/master/mkimage.sh
    chmod +x mkimage.sh
fi

# Custom profile
rm -rf ./profiles/$PROFILE_NAME
mkdir -p ./profiles/$PROFILE_NAME

cat > ./profiles/$PROFILE_NAME/packages <<EOF
alpine-base
python3
py3-pip
bash
EOF

mkdir -p ./profiles/$PROFILE_NAME/airootfs/root
cp "$APP_FILE" ./profiles/$PROFILE_NAME/airootfs/root/

mkdir -p ./profiles/$PROFILE_NAME/airootfs/etc/local.d
cat > ./profiles/$PROFILE_NAME/airootfs/etc/local.d/app.start <<'EOF'
#!/bin/sh
python3 /root/app.py
EOF
chmod +x ./profiles/$PROFILE_NAME/airootfs/etc/local.d/app.start

mkdir -p ./profiles/$PROFILE_NAME/airootfs/etc/runlevels/default
ln -sf /etc/init.d/local ./profiles/$PROFILE_NAME/airootfs/etc/runlevels/default/local

# Build ISO
./mkimage.sh \
    --tag "$ALPINE_VERSION" \
    --arch "$ARCH" \
    --repository "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/main" \
    --repository "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/community" \
    --outdir "$OUTDIR" \
    --profile "$PROFILE_NAME"
