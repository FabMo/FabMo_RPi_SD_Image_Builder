#!/bin/bash
# Quick fix to enable setup_wlan0_ap.service on existing FabMo systems
# This fixes the issue where AP SSID doesn't show the IP address

set -e

echo "=== Fix AP SSID IP Address Display ==="
echo ""
echo "This script will enable setup_wlan0_ap.service which updates the"
echo "Access Point SSID with the current IP address."
echo ""

# Check if source file exists
if [ ! -f "/fabmo/files/network_conf_fabmo/setup_wlan0_ap.service" ]; then
    echo "❌ ERROR: Source file not found!"
    echo "   Expected: /fabmo/files/network_conf_fabmo/setup_wlan0_ap.service"
    echo ""
    echo "This means either:"
    echo "  1. FabMo is not installed yet"
    echo "  2. FabMo needs to be updated to a version that includes this service"
    echo ""
    echo "Please update FabMo first, then run this script again."
    exit 1
fi

echo "✅ Source file found in FabMo"
echo ""

# Create symlink if it doesn't exist
if [ ! -L "/etc/systemd/system/setup_wlan0_ap.service" ] && [ ! -f "/etc/systemd/system/setup_wlan0_ap.service" ]; then
    echo "Creating symlink..."
    sudo ln -s /fabmo/files/network_conf_fabmo/setup_wlan0_ap.service /etc/systemd/system/
    echo "✅ Symlink created"
else
    echo "✅ Service file already exists"
fi

echo ""
echo "Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "Enabling setup_wlan0_ap.service..."
sudo systemctl enable setup_wlan0_ap.service

echo ""
echo "Starting setup_wlan0_ap.service..."
sudo systemctl start setup_wlan0_ap.service

echo ""
echo "=== Verification ==="
echo ""
echo "Service status:"
sudo systemctl status setup_wlan0_ap.service --no-pager -l

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The AP SSID should now update with the IP address."
echo "If you're currently in AP mode, you may need to reconnect to see the new name."
echo ""
echo "To check the service is working:"
echo "  sudo journalctl -u setup_wlan0_ap.service -f"
echo ""
