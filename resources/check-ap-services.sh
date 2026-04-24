#!/bin/bash
# Diagnostic script to check AP and network monitoring services

echo "=== FabMo Access Point Services Check ==="
echo ""

echo "1. Checking if setup-wlan0_ap.service is enabled:"
systemctl is-enabled setup-wlan0_ap.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Service is enabled"
else
    echo "   ❌ Service is NOT enabled (this is the problem!)"
fi

echo ""
echo "2. Checking if setup-wlan0_ap.service is running:"
systemctl is-active setup-wlan0_ap.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service is NOT running"
fi

echo ""
echo "3. Checking if service file exists:"
if [ -L "/etc/systemd/system/setup-wlan0_ap.service" ]; then
    echo "   ✅ Symlink exists: $(readlink -f /etc/systemd/system/setup-wlan0_ap.service)"
elif [ -f "/etc/systemd/system/setup-wlan0_ap.service" ]; then
    echo "   ✅ Service file exists (not symlinked)"
else
    echo "   ❌ Service file does NOT exist"
    echo "   Expected location: /etc/systemd/system/setup-wlan0_ap.service"
    echo "   Should be symlink to: /fabmo/files/network_conf_fabmo/setup-wlan0_ap.service"
fi

echo ""
echo "4. Checking if source file exists in FabMo:"
if [ -f "/fabmo/files/network_conf_fabmo/setup-wlan0_ap.service" ]; then
    echo "   ✅ Source file exists"
else
    echo "   ❌ Source file missing (FabMo not installed or outdated)"
fi

echo ""
echo "5. Checking network-monitor.service:"
systemctl is-enabled network-monitor.service 2>/dev/null && echo "   ✅ Enabled" || echo "   ❌ NOT enabled"
systemctl is-active network-monitor.service 2>/dev/null && echo "   ✅ Running" || echo "   ❌ NOT running"

echo ""
echo "6. Current AP SSID (if in AP mode):"
nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 || echo "   Not in AP mode or no active connection"

echo ""
echo "=== Troubleshooting ==="
echo ""
if systemctl is-enabled setup-wlan0_ap.service >/dev/null 2>&1; then
    echo "✅ Services appear to be configured correctly."
    echo "If AP name still doesn't show IP:"
    echo "  1. Check FabMo logs: journalctl -u setup-wlan0_ap.service -n 50"
    echo "  2. Restart the service: sudo systemctl restart setup-wlan0_ap.service"
    echo "  3. Check network-monitor: journalctl -u network-monitor.service -n 50"
else
    echo "❌ setup-wlan0_ap.service is NOT enabled!"
    echo ""
    echo "TO FIX:"
    echo "  1. Create symlink:"
    echo "     sudo ln -s /fabmo/files/network_conf_fabmo/setup-wlan0_ap.service /etc/systemd/system/"
    echo ""
    echo "  2. Reload systemd and enable:"
    echo "     sudo systemctl daemon-reload"
    echo "     sudo systemctl enable setup-wlan0_ap.service"
    echo "     sudo systemctl start setup-wlan0_ap.service"
    echo ""
    echo "  3. Verify:"
    echo "     sudo systemctl status setup-wlan0_ap.service"
fi

echo ""
