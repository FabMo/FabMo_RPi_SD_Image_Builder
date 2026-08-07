# Tailscale Remote Support for FabMo

## What is Tailscale?

This FabMo system includes **Tailscale** - optional remote support software that allows the FabMo support team to securely access your system when you need help.

**Important:** Tailscale is installed but **DISABLED by default**. It does nothing and has no network access until you explicitly enable it.

---

## Privacy & Security

### When Tailscale is DISABLED (default):
- ✓ No remote access possible
- ✓ No network connections made
- ✓ No data sent anywhere
- ✓ Completely isolated and inactive
- ✓ Your system operates exactly as if Tailscale wasn't installed

### When Tailscale is ENABLED (opt-in):
- All connections are encrypted using WireGuard VPN
- Only authorized FabMo support staff can access your system
- Access is controlled via Tailscale's zero-trust security model
- All connections are logged and auditable
- You can revoke access at any time
- No changes to your local network configuration required
- Works through NAT/firewalls without port forwarding

---

## How to Use

### Check Current Status
```bash
/fabmo-support/scripts/check-tailscale-status.sh
```

### Enable Remote Support
When you need help from FabMo support:

1. Contact FabMo support and request remote assistance
2. Support will provide you with an authentication key
3. Run the activation script:
   ```bash
   sudo /fabmo-support/scripts/enable-tailscale-support.sh
   ```
4. Enter the authentication key when prompted
5. Support team can now help you remotely

### Disable Remote Support
When you no longer need remote assistance:
```bash
sudo /fabmo-support/scripts/disable-tailscale-support.sh
```

---

## What Support Team Can Access

When Tailscale is enabled, FabMo support staff can:
- Access the FabMo dashboard in their web browser
- SSH into the system for diagnostics and fixes
- View logs and system status
- Make configuration changes (with your permission)

Support **cannot**:
- Access your system when Tailscale is disabled
- Connect without you enabling it and providing an auth key
- Access your local network or other devices
- See your activity when not connected

---

## Complete Removal

If you decide you never want remote support capability:

```bash
# Remove Tailscale completely
sudo apt remove --purge tailscale
sudo rm -rf /var/lib/tailscale
```

This completely removes Tailscale from your system.

---

## Troubleshooting

### Tailscale won't connect
1. Verify you have an active internet connection
2. Check that you're using a valid authentication key
3. Try disabling and re-enabling:
   ```bash
   sudo /fabmo-support/scripts/disable-tailscale-support.sh
   sudo /fabmo-support/scripts/enable-tailscale-support.sh
   ```

### Check service status manually
```bash
sudo systemctl status tailscaled
tailscale status
tailscale ip
```

### View logs
```bash
sudo journalctl -u tailscaled -n 50
```

---

## Web Console

You can manage your Tailscale connection at:
**https://login.tailscale.com**

From there you can:
- See all your connected devices
- Revoke access to specific devices
- View connection logs
- Manage access controls

---

## Questions?

For more information or questions about remote support:
- Email: support@fabmo.com
- Tailscale Documentation: https://tailscale.com/kb/

---

## Technical Details

**Installation Location:** `/usr/bin/tailscale`, `/usr/sbin/tailscaled`  
**Configuration:** `/etc/default/tailscaled`  
**State Directory:** `/var/lib/tailscale/`  
**Service:** `tailscaled.service` (systemd)
**Scripts:** `/fabmo-support/scripts/`
**Documentation:** `/fabmo-support/README-TAILSCALE.txt`

**Default State:** Installed but disabled  
**Network:** Outbound HTTPS only (443), no listening ports  
**Protocol:** WireGuard (modern, secure, fast VPN)  
**Vendor:** Tailscale Inc. (https://tailscale.com)
