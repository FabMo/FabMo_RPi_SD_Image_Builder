#!/bin/bash

# Check if SSID argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <NewSSID>"
    exit 1
fi

NEW_SSID="$1"

# Path to hostapd configuration file
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"

# Check if hostapd configuration file exists
if [ ! -f "$HOSTAPD_CONF" ]; then
    echo "hostapd configuration file does not exist at $HOSTAPD_CONF"
    exit 1
fi

# Update the SSID in the configuration file
sudo sed -i "s/^ssid=.*/ssid=$NEW_SSID/" $HOSTAPD_CONF

# Restart hostapd to apply changes
sudo systemctl stop wpa_supplicant
sudo systemctl restart hostapd
sudo systemctl restart dhcpcd
#sudo systemctl restart wpa_supplicant

echo "SSID changed to $NEW_SSID and hostapd restarted."
