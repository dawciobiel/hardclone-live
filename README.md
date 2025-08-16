# HardClone Live

Custom Clonezilla Live distribution with HardClone CLI and GUI applications for advanced partition backup and cloning operations.

## Features

- Based on Clonezilla Live
- Supports both BIOS and UEFI boot
- Includes Python 3.6+ and essential tools (dd, pv)
- Pre-installed HardClone CLI and GUI applications
- Automated ISO building via GitHub Actions

## Applications Included

- **HardClone CLI**: Command-line backup and cloning tool
- **HardClone GUI**: Graphical interface for backup operations
- All standard Clonezilla tools and utilities

## Building

The ISO is automatically built using GitHub Actions on every push to the main branch.

### Manual Build (Local)

```bash
# Build with Docker
docker build -t clonezilla-builder .
docker run --rm -v $(pwd):/workspace clonezilla-builder
```

### Build Requirements

- Docker
- Internet connection (to download Clonezilla and clone repositories)

## Download

Built ISOs are available in the GitHub Actions artifacts or releases section.


## Usage

1. Download the latest ISO from releases
2. Create bootable USB/DVD
3. Boot from the media
4. Use standard Clonezilla interface or launch HardClone tools:
   - CLI: Available in PATH as `hardclone`
   - GUI: Desktop shortcut or run `hardclone-gui`

## Application Sources

- CLI: [hardclone-cli](https://github.com/dawciobiel/hardclone-cli)
- GUI: [hardclone-gui](https://github.com/dawciobiel/hardclone-gui)

## License

This project combines Clonezilla Live with custom applications. Please refer to individual component licenses.
