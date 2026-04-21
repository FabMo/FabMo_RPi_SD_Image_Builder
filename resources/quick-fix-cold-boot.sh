#!/bin/bash
# POST-INSTALLATION FIX for white/red screen on RPi 5 cold boot
# 
# WHEN TO USE: Run this AFTER flashing the FabMo image to a new RPi 5 board
#              that shows the white/red "Install an OS" screen on first boot.
#
# The real cause: RPi 5 newer EEPROM has NET_INSTALL_AT_POWER_ON=1 by default
# This shows the "Install an OS" / Network Install UI on every cold power-up
# 
# This script applies the correct fix (or just use: sudo raspi-config)
#
# NOTE: This modifies the BOARD'S EEPROM, not the SD card. Each physical
#       RPi 5 board needs this done once, but it persists forever.

set -e

echo "=== RPi 5 Cold Boot White/Red Screen Fix ==="
echo ""
echo "This will disable the Network Install UI that appears on cold boot."
echo "The setting is stored in THIS BOARD'S EEPROM hardware, not the SD card."
echo ""
echo "You only need to run this ONCE per physical Raspberry Pi board."
echo ""
read -p "Press Enter to continue..."

echo ""
echo "Disabling Network Install UI in EEPROM..."

# Try raspi-config first (if function exists), otherwise use direct EEPROM edit
if grep -q "do_net_install" /usr/bin/raspi-config 2>/dev/null; then
    sudo raspi-config nonint do_net_install 1  # 1 = disable
else
    # Function doesn't exist in this raspi-config version - modify EEPROM directly
    echo "  raspi-config method not available, using direct EEPROM modification..."
    CURRENT_CONFIG=$(sudo rpi-eeprom-config)
    echo "$CURRENT_CONFIG" | sed 's/NET_INSTALL_AT_POWER_ON=1/NET_INSTALL_AT_POWER_ON=0/' > /tmp/bootconf.txt
    # If setting doesn't exist, add it
    if ! grep -q "NET_INSTALL_AT_POWER_ON" /tmp/bootconf.txt; then
        echo "NET_INSTALL_AT_POWER_ON=0" >> /tmp/bootconf.txt
    fi
    sudo rpi-eeprom-config --apply /tmp/bootconf.txt
    rm /tmp/bootconf.txt
fi

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
