# FabMo_RPi_SD_Image_Builder — notes for Claude

Semi-automated build of the FabMo Raspberry Pi SD image: a base Raspberry Pi
OS plus the engine, updater, fabmo-def, services, networking (AP / LAN /
direct-connect via NetworkManager, avahi/mDNS, dnsmasq), Tailscale for remote
support, and first-boot setup. Built once or twice a year; not a daily-change
repo. See ~/.claude/CLAUDE.md for the platform picture.

## Read first

`README.md` (top has current gotchas), `PROCEDUREdetails.txt`,
`FIRST_BOOT_SETUP.txt`, then the `TAILSCALE-*.md` set. `build-fabmo-image.sh`
is the main script; `restore-network-config.sh` is a recovery helper;
`resources/` holds files copied onto the image.

## Current decisions (Sept 2026)

- Base OS: **Raspberry Pi OS Legacy (Bookworm) 64-bit**. Trixie was tried in
  April 2026 and rejected for production (first-boot shell/desktop breakage;
  passwordless `sudo` disabled by default). Treat Trixie as a test track.
- RPi 5 8 GB boards may need `NET_INSTALL_AT_POWER_ON` disabled once in EEPROM
  via `raspi-config` — a board setting, not an image setting.
- Serial behavior changed in Bookworm; implications for the G2 connection are
  still being evaluated (engine issue).

## Conventions

- Anything that must change on an already-shipped image goes in
  **FabMo-Updater `patches/`**, not here. This repo is for new images.
- `maintained_in_fabmo_INFO_ONLY/` is reference copies of files whose source
  of truth is the engine repo. Don't edit them here.
- Shell scripts run as root during build; keep them idempotent and log what
  they change.

## Do not, without an explicit ask

- Change the base OS version or the NetworkManager/AP configuration — these
  are the two areas where a wrong change costs a full rebuild-and-retest cycle
  on real hardware.
