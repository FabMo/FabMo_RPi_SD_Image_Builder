# dnsmasq Configuration for FabMo

## Overview

The FabMo networking system uses dnsmasq to provide DHCP and DNS services. To prevent network disruption when connected to a LAN, dnsmasq uses different configurations depending on the active network profile.

## Configuration Files

- **dnsmasq.conf** - Main configuration file (loaded from /etc/dnsmasq.conf)
- **ap-only.conf** - DHCP only on wlan0_ap (used when connected to LAN via eth0)
- **direct-mode.conf** - DHCP on both wlan0_ap and eth0 (used for direct PC connection)

## How It Works

1. The `network-monitor.sh` script monitors the active NetworkManager profile on eth0
2. When the profile changes, it creates a symlink `/etc/dnsmasq.d/active-mode.conf` pointing to the appropriate config
3. dnsmasq is restarted to apply the new configuration

### LAN Mode (lan-connection profile active)
- Uses: `ap-only.conf`
- DHCP served on: wlan0_ap only
- eth0: No DHCP service (prevents interference with LAN DHCP server)
- AP available at: 192.168.42.1

### Direct Connection Mode (direct-connection profile active)
- Uses: `direct-mode.conf`
- DHCP served on: wlan0_ap AND eth0
- eth0: DHCP range 192.168.44.10-50
- AP available at: 192.168.42.1
- Direct connection at: 192.168.44.1

## Default Behavior

On first boot, the system defaults to `ap-only.conf` to ensure safe operation if connected to a network with existing DHCP infrastructure.

## Troubleshooting

# Check which configuration is active:

ls -l /etc/dnsmasq.d/active-mode.conf

# View Logs

sudo journalctl -u dnsmasq -f

## Manually Switch Modes

# Switch to ap-only mode
sudo ln -sf /etc/dnsmasq.d/ap-only.conf /etc/dnsmasq.d/active-mode.conf
sudo systemctl restart dnsmasq

# Switch to direct-mode
sudo ln -sf /etc/dnsmasq.d/direct-mode.conf /etc/dnsmasq.d/active-mode.conf
sudo systemctl restart dnsmasq

This solution ensures that dnsmasq will **never** serve DHCP on eth0 when connected to your LAN, eliminating the race condition that causes network disruption after power failures. The Raspberry Pi will only serve DHCP on eth0 when explicitly in direct-connection mode.
