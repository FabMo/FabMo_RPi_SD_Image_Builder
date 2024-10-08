#!/bin/sh

# Checks the systemd services running FabMo

echo "Checking the status of Key Fabmo services ============================"
echo " "
echo "----FabMo---------------------------------------------------"
systemctl --no-pager status fabmo.service
echo " "
echo "----Updater-------------------------------------------------"
systemctl --no-pager status fabmo-updater.service
echo " "
echo "----User Networking-----------------------------------------"
systemctl --no-pager status network-monitor.service
systemctl --no-pager status setup-wlan0_ap.service
echo " "
echo "----System Networking---------------------------------------"
systemctl --no-pager status NetworkManager
echo " "
systemctl --no-pager status dnsmasq
echo " "
systemctl --no-pager status hostapd
echo " "
echo " "



