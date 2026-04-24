# Missing Network Services in FabMo-Engine

## Issue

As of April 2026, the following systemd service files are **missing from the FabMo-Engine repository** but are referenced by the image build process:

1. **setup-wlan0_ap.service** ⚠️ **CRITICAL**
2. **export-netcfg-thumbdrive.service**
3. **export-netcfg-thumbdrive.path**

## Current Status

The build script (`build-fabmo-image.sh`) has been updated to gracefully handle missing services:
- ✅ Build will complete successfully even if services are missing
- ⚠️ Warning message displayed if `setup-wlan0_ap.service` is not found
- ❌ AP SSID will NOT show IP address without `setup-wlan0_ap.service`

## Impact

### Critical: setup-wlan0_ap.service
**Without this service:**
- Access Point (AP) SSID will show static name (e.g., "FabMo-XXXX")
- AP SSID will NOT update with current IP address
- Users won't see the IP in the WiFi network list
- Desktop IP display (via `ip-reporting.py`) will still work correctly

**This is the service you were missing that caused the AP IP issue!**

### Non-critical: export-netcfg-thumbdrive.*
**Without these services:**
- Network configuration export to USB thumbdrive may not work
- Less critical for basic operation

## What Needs to Be Done

### 1. Locate the Service Files

These services likely exist somewhere in the FabMo codebase or on older working systems. Check:
- Previous FabMo image builds
- FabMo development machines
- Git history of FabMo-Engine
- Older SD card images that had working AP IP display

### 2. Add Files to FabMo-Engine Repository

The files should be added to:
```
FabMo-Engine/
  └── files/
      └── network_conf_fabmo/
          ├── setup-wlan0_ap.service        ← ADD THIS
          ├── export-netcfg-thumbdrive.service  ← ADD THIS
          └── export-netcfg-thumbdrive.path     ← ADD THIS
```

### 3. Service File Format

Standard systemd service file format. Example structure for `setup-wlan0_ap.service`:

```ini
[Unit]
Description=Setup wlan0 Access Point with IP address in SSID
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/path/to/script/that/updates/ap/ssid.sh

[Install]
WantedBy=multi-user.target
```

### 4. Verify After Adding

Once added to FabMo-Engine:
1. Update FabMo on build machine
2. Rebuild SD image
3. Verify during build: "Enabled setup-wlan0_ap.service" message appears
4. Test AP mode: SSID should show IP address

## Temporary Workaround (Current Build)

For the current build without `setup-wlan0_ap.service`:

**Option 1: Manual Service Creation**
If you have the service file from a previous working system, you can manually install it:
```bash
# Copy service file to FabMo
sudo cp setup-wlan0_ap.service /fabmo/files/network_conf_fabmo/

# Create symlink
sudo ln -s /fabmo/files/network_conf_fabmo/setup-wlan0_ap.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable setup-wlan0_ap.service
sudo systemctl start setup-wlan0_ap.service
```

**Option 2: Use Previous Image**
If you have a previous FabMo image where AP IP display worked, extract the service files from that system.

## Build Script Behavior

The updated build script now:
- ✅ Checks if service files exist before creating symlinks
- ✅ Only enables services that were successfully symlinked
- ✅ Displays warning if critical services are missing
- ✅ Completes build successfully even with missing services

## Next Steps

1. **Immediate**: Document this issue for FabMo team
2. **Short-term**: Locate the missing service files from working systems
3. **Long-term**: Add service files to FabMo-Engine repository
4. **Future**: Update FabMo to latest version with services included

## Questions to Answer

1. Where do these services currently exist? (Check older images/systems)
2. What scripts do they call? (Find the actual implementation)
3. Who created them originally? (Git history might show)
4. Are there dependencies we're missing? (Other scripts/tools)

---

**Created**: April 24, 2026  
**Status**: Services missing from FabMo-Engine repo, build script updated to handle gracefully  
**Priority**: HIGH - AP IP display is a key feature
