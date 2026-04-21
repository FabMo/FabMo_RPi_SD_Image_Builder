# RPi 5 Boot Display Fix - Summary

## The Real Problem

The white/red screen with scrolling text on **cold boot only** (power-on) was caused by:

**RPi 5 EEPROM setting: `NET_INSTALL_AT_POWER_ON=1`**

- Newer 8GB RPi 5 boards ship with factory EEPROM that has this enabled by default
- Shows "Install an OS" / Network Install UI on every cold power-up
- **Setting lives in board's SPI EEPROM, not on the SD card**
- Older 4GB boards had EEPROM that predates this feature

## CRITICAL: Per-Board Configuration Required

**This cannot be fixed in the SD card image**. The EEPROM is hardware on the Raspberry Pi board itself, separate from the SD card. This means:

- ✅ Each physical RPi 5 board needs to be configured once
- ✅ The setting persists even when you swap SD cards
- ✅ You only need to fix it once per board, not once per image
- ❌ You cannot "bake" this fix into an image file
- ❌ Building the image with the fix only affects the build machine's board

## The Actual Fix

```bash
sudo raspi-config
# Navigate to: Advanced Options → Network Install UI → Disable
```

This writes `NET_INSTALL_AT_POWER_ON=0` to the EEPROM permanently.

**Alternative command (if available):**
```bash
sudo raspi-config nonint do_net_install 1  # 1 = disable
```

**Note**: The `do_net_install` function may not exist in older raspi-config versions (e.g., Bookworm legacy). If not available, the build script automatically falls back to direct EEPROM modification:

```bash
# Get current config, modify setting, and apply
CURRENT_CONFIG=$(sudo rpi-eeprom-config)
echo "$CURRENT_CONFIG" | sed 's/NET_INSTALL_AT_POWER_ON=1/NET_INSTALL_AT_POWER_ON=0/' > /tmp/bootconf.txt
sudo rpi-eeprom-config --apply /tmp/bootconf.txt
```

## What We Changed (And Why)

### ✅ KEPT - Valuable Improvements

These changes improve the boot experience regardless of the EEPROM issue:

**1. Plymouth Boot Splash Configuration**
- Extended display duration (3-5 seconds)
- FabMo logo replacement
- Proper theming (pix theme)
- Files: `/etc/plymouth/plymouthd.conf`, systemd service overrides

**2. Auto-Login Configuration**
- LightDM configured for automatic login as user `pi`
- No login prompt appears
- File: `/etc/lightdm/lightdm.conf.d/22-autologin.conf`

**3. Basic Firmware Display Settings** (config.txt)
- `disable_fw_kms_setup=1` - Disables rainbow splash on RPi 5
- `disable_splash=1` - Disables firmware splash screen
- `boot_delay=0` - Faster cold boot start
- `disable_overscan=1` - No black borders
- `avoid_warnings=1` - No firmware warnings overlay

**4. Reasonable Console Suppression** (cmdline.txt)
- `quiet` - Reduces kernel messages
- `loglevel=3` - Shows errors but not verbose info (was overly aggressive at 0)
- `console=tty3` - Redirects console to tty3 (invisible)
- `logo.nologo` - No Tux penguin logo
- `splash` - Enables Plymouth splash
- `plymouth.ignore-serial-consoles` - Prevents Plymouth conflicts

**5. Boot Parameter Enforcement Service**
- `/usr/local/bin/ensure-fabmo-boot-params.sh`
- `fabmo-boot-params.service`
- Maintains boot parameters if other processes modify them
- Now uses the cleaner parameter set

**6. Getty Service Configuration**
- Delays getty@tty1 to not conflict with Plymouth
- `TTYVTDisallocate=no` ensures smooth handoff
- Necessary for auto-login to work properly

### ❌ REVERTED - Unnecessary Workarounds

These were attempts to fix the firmware UI issue via kernel/boot parameters (didn't work):

**1. UART Disable Settings** (config.txt)
- ~~`uart_2ndstage=0`~~ - REMOVED
- ~~`enable_uart=0`~~ - REMOVED
- **Why reverted**: Not the cause of white/red screen, blocks serial debugging

**2. Overly Aggressive Console Suppression** (cmdline.txt)
- ~~`loglevel=0`~~ → Changed to `loglevel=3`
- ~~`rd.systemd.show_status=false`~~ - REMOVED
- ~~`rd.udev.log_level=0`~~ - REMOVED
- ~~`consoleblank=0`~~ - REMOVED
- **Why reverted**: Made debugging harder, didn't fix the real issue

## Updated Build Script

The `build-fabmo-image.sh` script now:

1. ✅ Applies cleaner boot parameters (loglevel=3, not 0)

2. ✅ Skips UART disable (unnecessary, blocks debugging)

3. ✅ Maintains all valuable Plymouth/auto-login configurations

4. ✅ Includes note that EEPROM settings are per-board, not per-image

5. ❌ Does NOT configure EEPROM (cannot be baked into image - must be done per-board)

## Scripts Available

### For Current Build (Manual Cleanup)
- **`resources/cleanup-aggressive-settings.sh`** - Removes overly aggressive settings from current system
- **`resources/quick-fix-cold-boot.sh`** - Applies EEPROM fix via raspi-config

### For Diagnostics
- **`resources/check-boot-config.sh`** - Verifies boot configuration, checks EEPROM setting

### For Automated Builds
- **`build-fabmo-image.sh`** - Now includes EEPROM fix and cleaner settings

## Expected Boot Sequence

After proper configuration, both cold boot (power-on) and warm boot (reboot) should show:

1. **Black screen** (brief, 1-2 seconds)
2. **FabMo logo** (Plymouth splash, 3-5 seconds)
3. **ShopBot desktop** (auto-login, no prompt)

**You should NEVER see:**
- White/red "Install an OS" screen
- Login prompt
- Scrolling console text
- Rainbow splash screen

## Testing

To verify the fix worked:

```bash
# Check EEPROM setting
vcgencmd bootloader_config | grep NET_INSTALL

# Should show: NET_INSTALL_AT_POWER_ON=0

# Test both boot types
sudo reboot           # Warm boot
# Then power cycle    # Cold boot
```

Both should produce identical clean boot sequences.

## Lessons Learned

1. **RPi 5 ≠ RPi 4**: New hardware, new EEPROM features
2. **EEPROM ≠ SD Card**: Settings persist in board firmware
3. **Factory EEPROM varies**: Newer boards have different defaults
4. **Check raspi-config first**: Advanced Options has RPi 5-specific settings
5. **Less is more**: Overly aggressive suppression makes debugging harder

## Documentation Updates

- **PROCEDUREdetails.txt**: Updated with post-installation EEPROM fix instructions for end users
- **README.md**: Clarifies EEPROM fix is per-board, not per-image
- **BOOT_FIX_SUMMARY.md**: This document (technical reference)
- **build-fabmo-image.sh**: Removed EEPROM modification (cannot be baked into image)

## Future Considerations

- EEPROM settings may change in future RPi 5 hardware revisions
- Always check `vcgencmd bootloader_config` on new boards
- Consider creating a welcome screen or first-run script that reminds users to disable Network Install UI
- Document this requirement in distribution materials and setup guides
- Serial console (UART) may be needed for debugging - settings allow re-enabling if needed
- Consider documenting other EEPROM settings that might affect FabMo
- Serial console (UART) may be needed for debugging - settings allow re-enabling if needed
