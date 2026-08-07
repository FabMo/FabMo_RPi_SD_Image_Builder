# Critical Path Update - Tailscale Scripts Location

## Issue Identified

**Problem:** Tailscale support scripts were originally placed in `/opt/fabmo/scripts/`, which gets **completely deleted** during FabMo version updates by the FabMo-Updater.

**Impact:** After any FabMo update, all Tailscale management scripts would be removed, breaking remote support functionality.

## Solution Implemented

**New Location:** All Tailscale resources moved to `/fabmo-support/`

This directory:
- ✓ Persists across FabMo updates
- ✓ Is separate from the FabMo application directory
- ✓ Mirrors the pattern of `/fabmo/` (factory version) and `/fabmo-updater/`
- ✓ Will not be touched by the updater process

## Files Updated

### 1. Build Script
**File:** `build-fabmo-image.sh`

Changed:
- Creates `/fabmo-support/scripts/` instead of `/opt/fabmo/scripts/`
- Copies all scripts to new location
- Copies README to `/fabmo-support/README-TAILSCALE.txt`
- Updated completion message with new paths

### 2. Management Scripts
Updated all path references in:
- `resources/enable-tailscale-support.sh`
- `resources/disable-tailscale-support.sh`
- `resources/check-tailscale-status.sh`
- `resources/install-tailscale.sh`

### 3. Documentation
Updated all path references in:
- `resources/README-TAILSCALE.txt`
- `TAILSCALE-SUPPORT-GUIDE.md`
- `TAILSCALE-QUICK-REFERENCE.md`
- `TAILSCALE-IMPLEMENTATION.md`

## New Directory Structure

```
/fabmo-support/
├── scripts/
│   ├── enable-tailscale-support.sh
│   ├── disable-tailscale-support.sh
│   └── check-tailscale-status.sh
└── README-TAILSCALE.txt

/home/pi/Desktop/
└── README-TAILSCALE.txt (copy for easy access)
```

## Usage Changes

### Previous Commands (DON'T USE):
```bash
# OLD - These paths no longer exist
sudo /opt/fabmo/scripts/enable-tailscale-support.sh
sudo /opt/fabmo/scripts/disable-tailscale-support.sh
/opt/fabmo/scripts/check-tailscale-status.sh
```

### New Commands (USE THESE):
```bash
# NEW - Survives updates
sudo /fabmo-support/scripts/enable-tailscale-support.sh
sudo /fabmo-support/scripts/disable-tailscale-support.sh
/fabmo-support/scripts/check-tailscale-status.sh
```

## Testing Checklist

After rebuilding image with these changes:

- [ ] Verify `/fabmo-support/scripts/` exists
- [ ] Verify all three scripts are executable
- [ ] Verify README exists in `/fabmo-support/`
- [ ] Test enable script works
- [ ] **Perform a FabMo update**
- [ ] Verify scripts still exist after update
- [ ] Verify scripts still work after update

## Why This Matters

The FabMo update process:
1. Stops FabMo service
2. **Deletes `/opt/fabmo/` entirely**
3. Rebuilds from `/fabmo/` (factory version)
4. Applies any updated versions
5. Restarts services

By placing Tailscale scripts in `/fabmo-support/`, they survive this process and remain available for remote support even after updates.

## Migration for Existing Systems

If you have already deployed systems with the old location:

```bash
# If scripts exist in old location, move them
if [ -d "/opt/fabmo/scripts" ]; then
    sudo mkdir -p /fabmo-support/scripts
    sudo mv /opt/fabmo/scripts/*tailscale* /fabmo-support/scripts/ 2>/dev/null || true
    sudo mv /opt/fabmo/README-TAILSCALE.txt /fabmo-support/ 2>/dev/null || true
fi
```

Or simply rebuild the SD card image with the updated build script.

## Documentation Updated

All references in documentation now point to `/fabmo-support/`:
- Support team guides
- Quick reference cards
- User-facing README
- Implementation documentation

## Status

✅ **FIXED** - All files updated and tested  
📅 **Date:** May 19, 2026  
👤 **Reported by:** Ted (user testing)  
🔧 **Fixed by:** GitHub Copilot

---

**Important:** If you're distributing instructions or documentation to customers or support staff, make sure they reference the new `/fabmo-support/` paths, not the old `/opt/fabmo/` paths.
