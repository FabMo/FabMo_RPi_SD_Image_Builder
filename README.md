# FabMo_RPi_SD_Image_Builder
Semi-automated SD-Image Maker for FabMo

## Important Notes

### RPi 5 Boot Display - EEPROM Configuration (Post-Installation)

**Issue**: Newer 8GB RPi 5 boards may show a white/red "Install an OS" screen on first boot.

**Cause**: Factory EEPROM has `NET_INSTALL_AT_POWER_ON=1` enabled by default (board hardware setting, not SD card).

**Fix** (one-time per board, after flashing image):
```bash
sudo raspi-config
# Navigate to: Advanced Options → Network Install UI → Disable
# Reboot
```

**Important**: This setting is stored in the board's EEPROM hardware, not on the SD card. Each physical board needs this configuration once, but it persists across SD card swaps and re-flashes.

See [BOOT_FIX_SUMMARY.md](BOOT_FIX_SUMMARY.md) for technical details.

---

### OS Version Selection (April 2026)

4_19_26 Difficult initializing "Trixie" first try so switched to legacy, but still supported bookworm for build today. Here is chatter with Perplexity.

Yes — for **your use case**, I would go back to **Bookworm** for production image creation. The official Raspberry Pi downloads page still offers **Bookworm as “Legacy” with security updates**, including Pi 5 compatible 64-bit images, all refreshed as of April 13, 2026. ([Raspberry Pi][1])

Why I’d choose it:

* What you just hit was not a small nuisance. You had a broken first-boot user shell and a failed desktop launch on a fresh image. For a production SD-card master image, that is exactly the sort of fragility you want to avoid.
* Bookworm is older, but it is still maintained by Raspberry Pi as a supported legacy branch with security updates. ([Raspberry Pi][1])
* Raspberry Pi itself treats major-version changes cautiously: when Trixie launched, they explicitly said they do **not** recommend or support in-place upgrades from Bookworm, which is another signal that a major OS jump is something to adopt only when you have a real reason. ([Raspberry Pi][2])

As to whether you **need** anything in Trixie right now: probably not.

Trixie is the current Debian 13-based Raspberry Pi OS, and Raspberry Pi has continued updating it, including a 6.2 update in April 2026. One notable change is that **new Trixie installs disable passwordless `sudo` by default**, which is more secure but may require a few setup-script adjustments if you rely on old assumptions. ([Raspberry Pi][3])

So the practical tradeoff is:

* **Trixie**: current branch, newer base, ongoing fixes, some behavior changes.
* **Bookworm Legacy**: still security-updated, Pi 5 compatible, much lower risk for a known-good appliance image. ([Raspberry Pi][1])

For FabMo, where your priorities are stability, repeatability, NetworkManager/AP behavior, and not having to rediscover OS quirks during the once-or-twice-a-year image build, I would treat Trixie as a **test track**, not the release base.

My recommendation would be:

**Use Raspberry Pi OS Legacy (Bookworm) 64-bit as your production base for now, and keep one separate Pi or SD card for Trixie evaluation.**

A reasonable trigger to move to Trixie later would be if you specifically need:

* a package version only available there,
* a kernel/driver fix that matters to your hardware,
* or you’ve run through your full FabMo image-build and field-test process on Trixie without surprises.

Right now, from what you just saw, I don’t think Trixie is earning its keep for you yet.

If you’d like, I can outline a simple “production image policy” for your team: when to stay on Bookworm, when to trial Trixie, and what 10 checks to run before promoting a new OS into your SD-card build.

[1]: https://www.raspberrypi.com/software/operating-systems/ "Raspberry Pi OS downloads – Raspberry Pi"
[2]: https://www.raspberrypi.com/news/trixie-the-new-version-of-raspberry-pi-os/ "Trixie — the new version of Raspberry Pi OS - Raspberry Pi"
[3]: https://www.raspberrypi.com/news/a-security-update-for-raspberry-pi-os/ "A security update for Raspberry Pi OS - Raspberry Pi"
