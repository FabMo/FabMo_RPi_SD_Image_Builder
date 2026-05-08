# Tailscale Quick Reference - FabMo Support Team

## Customer Activation (Quick Steps)

1. **Generate/provide auth key** (from https://login.tailscale.com/admin/settings/keys)
2. **Send customer instructions:**
   ```bash
   sudo /opt/fabmo/scripts/enable-tailscale-support.sh
   # Enter auth key when prompted
   ```
3. **Verify connection** in admin console
4. **Access via** Tailscale IP (100.x.y.z)

---

## Quick Access Commands

### Web Dashboard
```bash
# Find IP in admin console, then:
http://100.x.y.z
```

### SSH Access
```bash
ssh pi@100.x.y.z
# or using Tailscale SSH:
tailscale ssh pi@fabmo-abc12345
```

---

## Customer Commands Quick Reference

### Enable Support
```bash
sudo /opt/fabmo/scripts/enable-tailscale-support.sh
```

### Check Status
```bash
/opt/fabmo/scripts/check-tailscale-status.sh
# or manually:
tailscale status
```

### Disable Support
```bash
sudo /opt/fabmo/scripts/disable-tailscale-support.sh
```

### View IP
```bash
tailscale ip
```

---

## Troubleshooting Quick Fixes

### Won't Connect
```bash
# Customer runs:
sudo systemctl restart tailscaled
sudo tailscale down
sudo tailscale up --authkey=<NEW-KEY> --ssh
```

### Service Not Running
```bash
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
```

### Check Logs
```bash
sudo journalctl -u tailscaled -n 50
```

---

## Admin Console Quick Links

- **Machines:** https://login.tailscale.com/admin/machines
- **Auth Keys:** https://login.tailscale.com/admin/settings/keys
- **ACLs:** https://login.tailscale.com/admin/acls

---

## Auth Key Settings (Pilot Program)

When generating keys:
- ✓ Reusable
- ✓ Ephemeral
- ✓ Pre-approved
- Tags: `tag:fabmo-field-unit`
- Expiry: 90 days

---

## Security Checklist

- [ ] Use tagged devices
- [ ] Rotate keys quarterly
- [ ] Remove inactive devices weekly
- [ ] Get permission before accessing
- [ ] Document all access in ticket system
- [ ] Communicate with customer during session
- [ ] Offer to disable after support complete

---

## Important Notes

⚠️ **Never:**
- Share auth keys publicly
- Access without permission
- Make changes without customer notification

✓ **Always:**
- Document what you're doing
- Test changes
- Explain fixes to customer
- Update ticket system

---

## Emergency Contacts

- Support Lead: [NAME/EMAIL/PHONE]
- Tailscale Account Admin: [NAME/EMAIL]
- Security Team: [EMAIL]

---

*Print this card and keep at your desk for quick reference*
