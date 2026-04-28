# Maintained in FabMo - Information Only

## Purpose

This directory contains **shadow/reference copies** of files that are actually maintained in the FabMo-Engine repository. These copies are here for:

1. **Documentation** - Understanding what the image builder expects
2. **Reference** - Checking file contents without accessing FabMo repo
3. **Backup** - Preserving known-good versions if files go missing

⚠️ **IMPORTANT**: These are **NOT** the authoritative versions. Changes should be made in the FabMo-Engine repository, not here.

## Files Included

### network_conf_fabmo/

Files from FabMo-Engine at `/fabmo/files/network_conf_fabmo/`:

- **setup_wlan0_ap.service** - Systemd service for AP SSID management
- **setup_wlan0_ap.sh** - Script that restarts hostapd for AP
- **ip-reporting.py** - Python script that:
  - Displays IP address on desktop
  - Updates AP SSID to include IP address
  - Monitors network connections (eth > wifi > ap priority)
- **ip-reporting.sh** - Shell wrapper that launches ip-reporting.py

**Critical Note**: The `setup_wlan0_ap.service` and `setup_wlan0_ap.sh` files were accidentally deleted from FabMo-Engine in early 2026 and restored in April 2026. These files are **essential** for the AP SSID to show the current IP address.

### tools/

Files from FabMo-Engine at `/fabmo/files/tools/`:

- **ck_services.sh** - Diagnostic script to check FabMo service status
  - Symlinked to `/usr/local/bin/ck_services` during image build
  - Enhanced April 2026 to show AP SSID and network mode

## How These Files Are Used in Image Build

During the SD card image build process (`build-fabmo-image.sh`):

1. **FabMo-Engine** is cloned/installed to `/fabmo`
2. **Symlinks** are created from `/etc/systemd/system/` to the service files in `/fabmo/files/network_conf_fabmo/`
3. **Services** are enabled: `systemctl enable setup_wlan0_ap.service`
4. **Tool scripts** are symlinked to `/usr/local/bin/`

This allows FabMo updates to update these files without requiring a full image rebuild.

## Redundancy Considerations

Having these files in two places creates potential issues:

### Risks
- **Out of sync** - This copy may become outdated if FabMo-Engine changes
- **Confusion** - Unclear which version is "correct"
- **Merge conflicts** - If both change independently

### Benefits
- **Recovery** - Can restore missing files from this repo
- **Documentation** - Easier to see what the build expects without checking out FabMo
- **Version control** - Can track when files were changed in this context

## Maintenance Guidelines

1. **Never edit these files directly** - Make changes in FabMo-Engine
2. **Update periodically** - Sync from FabMo-Engine when significant changes occur
3. **Document changes** - Note in commit message when these copies are updated
4. **Check during builds** - Verify build script finds files in FabMo, not here

## File History

### April 2026
- **Restored**: `setup_wlan0_ap.service` and `setup_wlan0_ap.sh` after accidental deletion
- **Enhanced**: `ck_services.sh` to show AP SSID and network mode summary
- **Created**: This README and shadow copy system

## Related Build Script References

In `build-fabmo-image.sh`:

```bash
# Symlinks created for network services
SERVICES=("network-monitor.service" "setup_wlan0_ap.service" ...)
for SERVICE in "${SERVICES[@]}"; do
    ln -s "/fabmo/files/network_conf_fabmo/$SERVICE" /etc/systemd/system/
done

# Services enabled
systemctl enable setup_wlan0_ap.service

# Tool symlinks
ln -sf /fabmo/files/tools/ck_services.sh /usr/local/bin/ck_services
```

## Verification

To verify the AP SSID feature is working:

```bash
# Check service is enabled
systemctl is-enabled setup_wlan0_ap.service

# Check current AP SSID
nmcli -t -f 802-11-wireless.ssid connection show wlan0_ap

# Run diagnostic
ck_services
```

The AP SSID should show the format: `ToolName-MODE@IP` (e.g., `FabMo-5124-ap@192.168.42.1`)

---

**Last Updated**: April 25, 2026  
**Maintained By**: FabMo project  
**Authoritative Source**: https://github.com/FabMo/FabMo-Engine
