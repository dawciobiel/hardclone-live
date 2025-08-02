# Hardclone Live (CLI version)

This repository builds a minimal Ubuntu 24.04 LTS live ISO (CLI-only) with:
- Live + persistent support
- Single user `liveuser` with password `live` and full sudo access
- UEFI + BIOS boot support
- Directory `/home/liveuser/Apps/` prepared for AppImage binaries

## Usage
- Push changes to `main` or trigger manually to build ISO
- Download the `.iso` from GitHub Actions artifacts