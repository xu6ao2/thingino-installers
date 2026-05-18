---
description: Repository Information Overview
alwaysApply: true
---

# Thingino Installers Information

## Summary
Thingino Installers aggregates prebuilt SD card images, supporting assets, and Bash automation to flash Thingino firmware onto a range of Ingenic-based IP cameras. The top-level `README.md` frames the repo for both end users, who download the zip under each camera-specific directory, and developers, who can regenerate installers via `make_installers.sh`. The workflow emphasizes reversible flashing when possible, regular post-install firmware updates, and coordination with the WL Tech Blog community resources (YouTube tutorials plus Discord support). Each camera folder documents device-specific instructions, while shared tooling (assets, Docker environment, and shell scripts) standardizes artifact creation and maintenance.

## Structure
- Camera installers: individual directories such as `aobocam-a12/`, `aoqee-c1/`, `aosu-c5l/`, `cinnado-d1/`, `galayou-g2/`, `galayou-g7/`, `galayou-y4/`, `jooan-a2r-u/`, `jooan-a6m-u/`, `jooan-q3r/`, `sonoff-slim-gen-2/`, `tapo-c100/`, `wansview-g6/`, `wansview-w7/`, `wuuk-y0310/`, `wuuk-y0510/`, `wyze-cam-2/`, `wyze-cam-3/`, `wyze-cam-pan-v1/`, `wyze-cam-pan-v2/`, plus others such as `aobocam-a12/` and `galayou-g7/`. Each holds a README describing flashing/recovery steps alongside one or more installer zip archives (and in the Wyze V3 case, the large `sd.img`).
- `assets/`: shared binaries and scripts (`busybox-mipsel-linux-gnu`, `demo.bin`, per-model factory scripts, diagnostic helpers) referenced by the build script; its README clarifies these support files are build-time dependencies rather than direct user downloads.
- `diagnostics/`: provides `diagnostics.zip` and a README describing the audio-confirmed logging process for troubleshooting cams that still boot.
- Root-level automation: `make_installers.sh` orchestrates image construction; `sd.fdisk` captures the FAT partitioning scheme; `docker-run.sh`, `docker-compose.yaml`, and `Dockerfile` scaffold the privileged Ubuntu container for consistent builds; helper directories `tmp/` (created at runtime) and `mnt/` (mount point) support image assembly; `sd.img` and `sd-base.img` act as working images when building locally.
- Miscellaneous: `.gitignore` filters large artifacts, `docker-run.sh` wraps compose lifecycle commands, and miscellaneous large archives (`diagnostics.zip`, camera-specific zips) are versioned for distribution.

## Language & Runtime
**Language**: Bash plus auxiliary shell utilities interacting with binary firmware blobs.
**Version**: Script assumes a GNU/Linux environment with `bash` 4+, GNU coreutils, and privileged access to loop devices; the provided Docker image derives from `ubuntu:latest`, effectively pinning to the current LTS rolling tag at build time.
**Build System**: Custom Bash pipeline defined in `make_installers.sh`, using functions such as `new_image`, `add_uboot`, and per-device `do_*` targets; partitioning relies on `sfdisk`, filesystem creation on `mkfs.vfat`, image manipulation on `losetup` and `dd`, and packaging on `zip`/`unzip`.
**Package Manager**: Apt (within the container) installs `sudo`, `curl`, `git`, `vim`, `wget`, `zip`, `unzip`, `dosfstools`, `fdisk`, `util-linux`, `systemd`, and `udev`, satisfying tooling requirements called from the Bash scripts.

## Dependencies
**Main Dependencies**:
- Core Linux utilities: `dd`, `cp`, `mkfs.vfat`, `losetup`, `mount`, `umount`, `sfdisk`, and `sync` (implicitly provided by the host or container) drive image creation in `make_installers.sh:23-77`.
- Network + archive tooling: `wget` fetches firmware and bootloader artifacts (`get_asset`), while `zip`/`unzip` handle installer packaging (`make_installers.sh:85-199`).
- Firmware sources: GitHub releases from `themactep/thingino-firmware` supply device-specific binaries; `gtxaspec/ingenic-u-boot-xburst1` provides U-Boot images consumed in `add_uboot`; `wz-neos-upgrader.zip` (cached under `assets/`) seeds Wyze installers.
- Embedded helpers: `assets/busybox-mipsel-linux-gnu` is copied into device partitions (`do_aobocam_a12`), and per-vendor factory scripts (e.g., `assets/wuuk-y0510-factory.sh`, `assets/sonoff-slim-gen2-install.sh`) are injected into the installer root.

**Development Dependencies**:
- Docker Engine + Compose: required to run `docker-run.sh` or `docker-compose` targets that mount `/dev`, `/run`, and `/sys` for privileged loop-device access at build time.
- Zip manipulation tools for end users (e.g., Rufus or Raspberry Pi Imager) are referenced in the Wyze V3 README but not bundled; they remain implicit consumable dependencies when flashing devices on host machines.

## Build & Installation
```bash
# Build all installers on a native Linux host
tsudo ./make_installers.sh all

# Build a specific device image (names match function suffixes without `do_`)
./make_installers.sh wyze_cam_2

# Clear cached downloads stored under ./tmp
./make_installers.sh clean

# Launch the privileged Ubuntu builder container and enter it interactively
./docker-run.sh up

# Rebuild or access the container lifecycle
docker-run.sh build|enter|down|cleanup|refresh
```
`make_installers.sh` dynamically enumerates targets (via `grep "^do_"`) for the usage banner and in the `make_all` helper. Each `do_*` function follows a consistent pattern: call `new_image` to prepare a 120 MB FAT-formatted SD image using `sd.fdisk`, copy assets and firmware into the mounted `mnt/` directory, optionally patch U-Boot via `add_uboot`, close and unmount the loop device, and compress the resulting `sd.img` into the camera’s directory. Functions exist for Wyze (V2, V3, Cam Pan V1/V2), Wuuk (Y0310, Y0510), Wansview (G6 variants, W7 variants, Galayou rebrands), Cinnado D1, Tapos, AOQEE C1, Jooan (A2R-U, A6M-U, Q3R), Sonoff Slim Gen 2, Aobocam A12, Galayou G2/G7/Y4, AOSU C5L, diagnostics images, and more. Because the script downloads daily firmware builds via `get_asset`, rerunning targets after upstream releases automatically refreshes payloads while caching prior downloads in `tmp/` for speed.

## Main Files & Entry Points
- `README.md`: describes supported camera roster, differentiates end-user vs developer workflows, and links to WL Tech Blog tutorial resources and Discord support (lines 7-63).
- `make_installers.sh`: central automation entry point, defining cleanup traps, image lifecycle helpers, firmware download logic, and per-device builder functions (lines 1-539).
- `sd.fdisk`: partitions each generated `sd.img` into a single FAT16 (type `0x0c`) partition sized to 243,712 sectors, ensuring compatibility with even 128 MB cards.
- `assets/*.sh` and binary payloads: vendor-specific factory scripts (`aobocam-a12-factory.sh`, `wuuk-y0510-factory.sh`, `sonoff-slim-gen2-install.sh`, `runonce.sh`) and supporting binaries (`busybox-mipsel-linux-gnu`, `demo.bin`) injected into installers or diagnostics images.
- Camera README files (e.g., `wyze-cam-3/README.md`, `wuuk-y0310/README.md`): outline per-device installation flow, reversibility notes, video references, and troubleshooting steps, ensuring users follow hardware-specific guidance.
- `diagnostics/README.md`: documents the spoken confirmation log-collector workflow for bricked-yet-booting devices, aligning with the `diagnostics.zip` generated by `do_diagnostics`.
- `docker-run.sh` and `docker-compose.yaml`: wrap container lifecycle tasks, ensuring the builder runs in a privileged Ubuntu environment with host device passthrough; `docker-run.sh` normalizes command verbs for contributors.

## Docker
**Dockerfile**: `Dockerfile`
**Image**: Built locally from `ubuntu:latest` with user `thingino`
**Configuration**: The image installs the full toolchain (sudo, networking utilities, compression tools, storage utilities, systemd/udev) required for SD image assembly. It creates a passwordless `thingino` user, switches to `/home/thingino/bin`, and launches `bash` by default.

`docker-compose.yaml` defines the `thingino-image-builder-dev` service, mounting the repo into the container, binding `/sys`, `/run`, and `/dev` so loop devices and udev rules function, setting `privileged: true`, and keeping the container alive via `sleep infinity`. Developers generally run `./docker-run.sh up` to build the image, start the service, and open an interactive shell. Subsequent commands like `docker-run.sh enter` reattach to the running container, while `docker-run.sh refresh` rebuilds the image after dependency changes and restarts the service. Cleanups remove the compose stack and associated image, freeing disk space between build sessions.

## Usage & Operations
- End users typically download the prebuilt zips in their camera’s directory and follow the README instructions: flash the `sd.img` or zip contents onto a 128 MB+ SD card with tools such as Rufus/Raspberry Pi Imager, insert into the powered-down camera, wait for provisioning tones or LEDs, then upgrade to the latest Thingino firmware via the UI or `sysupgrade` as described in `wyze-cam-3/README.md:20-25`.
- Reversal instructions (when available) live inside each camera README; for Wyze V3, users store `combined_backup.bin`, rename it to `autoupdate-full.bin`, copy it alone onto the SD card, insert it, and wait for factory firmware restoration (`wyze-cam-3/README.md:31-40`).
- Diagnostics workflow involves flashing `diagnostics/diagnostics.zip` onto an SD card, listening for the spoken confirmation to ensure the log capture finished, then reading the log from the card, as outlined in `diagnostics/README.md`.
- Contributors extending installer coverage add new `do_<target>()` functions to `make_installers.sh`, sourcing firmware URLs from the Thingino release channel and, if necessary, introducing new asset scripts under `assets/` referenced by the new builder function.
