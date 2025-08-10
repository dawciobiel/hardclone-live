#!/bin/sh
set -euo pipefail

# builders/alpine-v2/build-my-live.sh
# Tworzy minimalne Alpine Live ISO przy pomocy mkimage.sh
# - ISO trafia do /workspace/artifacts/alpine/
# - app.py kopiowany z /workspace/builders/alpine-v2/app.py

ALPINE_VERSION="v3.20"
ARCH="x86_64"
PROFILE="my-python-live"
OUTDIR="/workspace/artifacts/alpine"
PROFILES_DIR="./profiles"

echo "[0] Working dir: $(pwd)"
echo "[1] Przygotowanie katalogów..."
mkdir -p "$OUTDIR"
mkdir -p "$PROFILES_DIR/$PROFILE/airootfs/root"

# Pobierz mkimage.sh jeśli nie ma
if [ ! -f ./mkimage.sh ]; then
  echo "[2] Pobieram mkimage.sh..."
  wget -q -O mkimage.sh "https://gitlab.alpinelinux.org/alpine/mkimage/-/raw/master/mkimage.sh"
  chmod +x mkimage.sh
fi

# Utwórz plik packages dla profilu
echo "[3] Tworzenie listy pakietów profilu..."
cat > "$PROFILES_DIR/$PROFILE/packages" <<EOF
alpine-base
python3
py3-pip
bash
openrc
EOF

# Skopiuj aplikację (jeśli nie ma, utwórz prosty placeholder)
echo "[4] Kopiowanie app.py do profilu..."
if [ -f /workspace/builders/alpine-v2/app.py ]; then
  cp /workspace/builders/alpine-v2/app.py "$PROFILES_DIR/$PROFILE/airootfs/root/"
else
  cat > "$PROFILES_DIR/$PROFILE/airootfs/root/app.py" <<'PY'
print("Hello from Live Python app (placeholder)!")
PY
fi

# Dodaj skrypt autostartowy w local.d (OpenRC local service)
echo "[5] Dodawanie autostartu (local.d)..."
mkdir -p "$PROFILES_DIR/$PROFILE/airootfs/etc/local.d"
cat > "$PROFILES_DIR/$PROFILE/airootfs/etc/local.d/start-myapp.start" <<'EOF'
#!/bin/sh
# delay small amount to let system settle
sleep 1
echo "Uruchamiam /root/app.py..."
/usr/bin/python3 /root/app.py
EOF
chmod +x "$PROFILES_DIR/$PROFILE/airootfs/etc/local.d/start-myapp.start"

# Upewnij się, że lokalny skrypt zostanie uruchomiony (link w runlevels)
mkdir -p "$PROFILES_DIR/$PROFILE/airootfs/etc/runlevels/default"
ln -sf /etc/init.d/local "$PROFILES_DIR/$PROFILE/airootfs/etc/runlevels/default/local" || true

# Uruchom mkimage.sh
echo "[6] Wywołanie mkimage.sh (to może potrwać kilka minut)..."
./mkimage.sh \
  --tag "$ALPINE_VERSION" \
  --arch "$ARCH" \
  --repository "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/main" \
  --repository "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/community" \
  --outdir "$OUTDIR" \
  --profile "$PROFILE"

echo "[7] Build zakończony. Zawartość katalogu $OUTDIR:"
ls -lah "$OUTDIR" || true
echo "Gotowe. Pobierz ISO z artefaktów GitHub Actions (artifacts/alpine/*.iso)"
