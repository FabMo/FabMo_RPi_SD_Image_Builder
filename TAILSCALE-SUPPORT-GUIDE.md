# Tailscale Support Guide for FabMo Support Team

## Overview

Tailscale enables secure remote support for FabMo units in the field. This guide covers setup, usage, and best practices for the support team.

---

## Prerequisites

### Tailscale Account Setup

1. Create a FabMo organization account at https://login.tailscale.com
2. Invite all support team members to the organization
3. Configure ACL (Access Control Lists) for security

### Recommended ACL Configuration

```json
{
  "tagOwners": {
    "tag:fabmo-field-unit": ["autogroup:admin"],
    "tag:support-team": ["autogroup:admin"]
  },
  "acls": [
    {
      // Support team can access field units
      "action": "accept",
      "src": ["tag:support-team"],
      "dst": ["tag:fabmo-field-unit:*"]
    },
    {
      // Field units cannot initiate connections to support team
      "action": "deny",
      "src": ["tag:fabmo-field-unit"],
      "dst": ["tag:support-team:*"]
    }
  ]
}
```

---

## Generating Authentication Keys

### For Pilot Program (Reusable Keys)

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key"
3. Configure:
   - **Reusable:** ✓ Enabled (allows use on multiple devices)
   - **Ephemeral:** ✓ Enabled (devices disappear when offline)
   - **Pre-approved:** ✓ Enabled (no manual approval needed)
   - **Tags:** `tag:fabmo-field-unit`
   - **Expiry:** 90 days (or as needed)

4. Save the key securely (e.g., password manager, encrypted doc)

### For Production (One-Time Keys)

For production use, disable "Reusable" to generate one-time keys per customer for better security tracking.

---

## Customer Onboarding Process

### When Customer Requests Support

1. **Send the auth key** via secure channel (email, phone, encrypted chat)
2. **Provide instructions:**
   ```
   To enable remote support on your FabMo system:
   
   1. Open a terminal on your FabMo system
   2. Run: sudo /opt/fabmo/scripts/enable-tailscale-support.sh
   3. Enter the authentication key when prompted: [INSERT KEY]
   4. Confirm completion
   
   Once connected, our support team can access your system remotely.
   ```

3. **Verify connection:**
   - Check Tailscale admin console for new device
   - Note the assigned IP (100.x.y.z)

4. **Communicate access details:**
   ```
   Your system is now connected for remote support.
   
   You can:
   - Check status: /opt/fabmo/scripts/check-tailscale-status.sh
   - Disable support: sudo /opt/fabmo/scripts/disable-tailscale-support.sh
   - View our access: https://login.tailscale.com
   ```

---

## Accessing Customer Systems

### Via Web Dashboard

1. Find the device in Tailscale admin console
2. Note its Tailscale IP (e.g., 100.64.23.45)
3. Open browser to: `http://100.64.23.45`
4. Access FabMo dashboard as normal

### Via SSH

```bash
# Find device IP in Tailscale console or run:
tailscale status

# SSH into the system
ssh pi@100.64.23.45

# Default password: (use standard FabMo password)
```

### Via Tailscale SSH (More Secure)

If enabled, Tailscale SSH provides better auditability:

```bash
# No password needed, uses Tailscale auth
tailscale ssh pi@fabmo-abc12345
```

---

## Support Session Best Practices

### Before Making Changes

1. **Communicate:** Always tell the customer what you're doing
2. **Document:** Note the issue and planned fix in ticket system
3. **Backup:** Consider backing up configs before changes
4. **Permission:** Get explicit permission for significant changes

### During Support

- Keep customer informed of progress
- Explain what you're finding and doing
- Ask before rebooting or making disruptive changes
- Document any unusual findings

### After Support

1. **Test:** Verify the fix works
2. **Document:** Update ticket with resolution
3. **Communicate:** Explain to customer what was fixed
4. **Optional:** Ask customer if they want to disable Tailscale:
   ```
   sudo /opt/fabmo/scripts/disable-tailscale-support.sh
   ```
5. **Remove device** from Tailscale if using ephemeral keys (automatic) or manually if needed

---

## Security & Privacy Guidelines

### DO:
- ✓ Use tagged devices (tag:fabmo-field-unit)
- ✓ Rotate authentication keys periodically
- ✓ Remove old/unused devices from admin console
- ✓ Use ephemeral keys when possible
- ✓ Enable audit logging
- ✓ Respect customer privacy
- ✓ Only access systems with explicit permission

### DON'T:
- ✗ Share auth keys publicly or via insecure channels
- ✗ Leave devices connected indefinitely without reason
- ✗ Access customer systems without permission/ticket
- ✗ Share Tailscale admin credentials
- ✗ Install Tailscale on customer systems without explaining it

---

## Troubleshooting

### Device Won't Connect

1. **Check internet connection** on customer's system
2. **Verify auth key** is correct and not expired
3. **Check service status:**
   ```bash
   sudo systemctl status tailscaled
   sudo journalctl -u tailscaled -n 50
   ```
4. **Try reconnecting:**
   ```bash
   sudo tailscale down
   sudo tailscale up --authkey=<key> --ssh
   ```

### Can't Access Dashboard/SSH

1. **Verify device is online** in Tailscale console
2. **Check Tailscale is running** on support computer
3. **Ping the device:**
   ```bash
   ping 100.x.y.z
   ```
4. **Check ACLs** in Tailscale admin console
5. **Verify firewall** on customer system (usually not an issue)

### Device Shows as Offline

- Device is powered off or disconnected from internet
- Tailscale service stopped on device
- Auth key expired (needs re-authentication)

---

## Monitoring & Management

### Tailscale Admin Console

View all connected devices:
https://login.tailscale.com/admin/machines

Features:
- See all connected FabMo units
- View last seen timestamps
- Disable/remove devices
- View connection logs
- Manage ACLs

### Regular Maintenance

- **Weekly:** Review connected devices, remove inactive ones
- **Monthly:** Rotate authentication keys
- **Quarterly:** Audit ACLs and access logs
- **Annually:** Review security policies

---

## Customer Communication Templates

### Initial Introduction

```
Subject: Remote Support Option for Your FabMo System

Your FabMo system includes an optional remote support feature using 
Tailscale (tailscale.com), which allows our team to help you remotely 
when needed.

Important: This feature is disabled by default and only activates when 
you choose to enable it.

For more information, see: /opt/fabmo/README-TAILSCALE.txt on your system

If you need remote assistance, contact us and we'll guide you through 
the simple activation process.
```

### Support Request Response

```
Subject: Remote Support Access Instructions

To allow our support team to assist you remotely:

1. Open a terminal on your FabMo system
2. Run: sudo /opt/fabmo/scripts/enable-tailscale-support.sh
3. Enter this authentication key: [KEY]
4. Reply to confirm connection

This creates a secure VPN connection. You can disable it anytime by running:
sudo /opt/fabmo/scripts/disable-tailscale-support.sh

Questions? Call us at [SUPPORT NUMBER]
```

### Post-Support Follow-Up

```
Subject: Remote Support Session Complete

We've completed the remote support session for [ISSUE].

Summary:
- Issue: [DESCRIPTION]
- Resolution: [WHAT WAS DONE]
- Status: [RESOLVED/NEEDS MONITORING/etc]

Your remote support connection is still active. You can:
- Leave it enabled for future support (no security concern)
- Disable it by running: sudo /opt/fabmo/scripts/disable-tailscale-support.sh
- Check status anytime: /opt/fabmo/scripts/check-tailscale-status.sh

Thank you for using FabMo!
```

---

## Frequently Asked Questions

### Can customers see when we're connected?

Yes, they can run `tailscale status` or check the Tailscale web console to see active connections.

### What if customer is behind corporate firewall?

Tailscale works through most firewalls (uses HTTPS/443). In rare cases with very restrictive firewalls, it may not connect.

### Can we access their local network?

No. Tailscale only provides access to the specific FabMo device, not the customer's entire network.

### What if authentication key is compromised?

1. Immediately revoke the key in Tailscale admin console
2. Remove any unauthorized devices
3. Generate a new key
4. Investigate how compromise occurred

### How much does Tailscale cost?

Free tier covers small deployments. For larger scale (100+ devices), see Tailscale pricing at https://tailscale.com/pricing

---

## Additional Resources

- **Tailscale Documentation:** https://tailscale.com/kb/
- **Tailscale Admin Console:** https://login.tailscale.com
- **Tailscale Status:** https://status.tailscale.com
- **FabMo Support KB:** [YOUR INTERNAL KB]

---

## Contact

For questions about this guide or Tailscale setup:
- **Support Lead:** [NAME/EMAIL]
- **IT/Security Team:** [NAME/EMAIL]

Last Updated: [DATE]
Version: 1.0
