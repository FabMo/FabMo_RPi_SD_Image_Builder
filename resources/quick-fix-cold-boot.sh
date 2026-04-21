#!/bin/bash
# ACTUAL FIX for white/red screen on RPi 5 cold boot
# 
# The real cause: RPi 5 newer EEPROM has NET_INSTALL_AT_POWER_ON=1 by default
# This shows the "Install an OS" / Network Install UI on every cold power-up
# 
# This script applies the correct fix via raspi-config

set -e

echo "=== RPi 5 Cold Boot White/Red Screen Fix ==="
echo ""
echo "This will disable the Network Install UI that appears on cold boot."
echo "The setting is stored in the board's EEPROM, not on the SD card."
echo ""
read -p "Press Enter to continue..."

echo ""
echo "Disabling Network Install UI in EEPROM..."
sudo raspi-config nonint do_net_install 1  # 1 = disable

echo ""
echo "=== Fix Applied ==="
echo ""
echo "The Network Install UI has been disabled."
echo "Reboot to verify the fix: sudo reboot"
echo ""
echo "You should now see:"
echo "  1. Black screen briefly"
echo "  2. FabMo logo (3-5 seconds)"
echo "  3. ShopBot desktop"
echo ""
echo "You should NO LONGER see the white/red 'Install an OS' screen."
echo ""
echo ""
echo "Now power off completely: sudo poweroff"
echo "Wait 10 seconds, then power on to test"
echo ""
