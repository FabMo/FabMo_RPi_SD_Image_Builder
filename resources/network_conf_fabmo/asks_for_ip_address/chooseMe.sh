#!/usr/bin/bash

# "$MODE" - this is a convenience variable so the scripts
# in the different mode directories can be identical other 
# than this variable. It may be we can use a single script
# that gets this variable as a parameter

MODE="asks_for_ip_address"

# source files
DHCPCD_SOURCE="/etc/network_conf_fabmo/$MODE/dhcpcd.conf"
DNSMASQ_SOURCE="/etc/network_conf_fabmo/$MODE/dnsmasq.conf"
RESOLVED_SOURCE="/etc/network_conf_fabmo/$MODE/resolved.conf"

#target files
DHCPCD_TARGET="/etc/dhcpcd.conf"
DNSMASQ_TARGET="/etc/dnsmasq.conf"
RESOLVED_TARGET="/etc/systemd/resolved.conf"

# copy new files in
cp $DHCPCD_SOURCE $DHCPCD_TARGET
cp $DNSMASQ_SOURCE $DNSMASQ_TARGET
cp $RESOLVED_SOURCE $RESOLVED_TARGET

## ORIGINAL: restart the relevant daemons
#systemctl restart systemd-resolved
#systemctl restart hostapd
#systemctl restart dnsmasq

# NEW - including setting wifi - restart the relevant daemons
# Doing a restart of everything we are interested in (maybe just first time?)
#   At start up, we should have all available networking up and AP-ssid set to FabMo-???>AP:192.168.42.1
#   ... without FabMo starting. FabMo can add Wifi and it controls/updates the detailed ssid display.
# This system is only used at the point that we are switching the ethernet connection!
##systemctl stop hostapd
systemctl stop wpa_supplicant
sleep 1
iw phy phy0 interface add uap0 type __ap
sleep 1
ifconfig uap0 up
sleep 1
systemctl start wpa_supplicant
sleep 1
wpa_cli -i wlan0 reconfig
sleep 1
systemctl restart dhcpcd
sleep 1
systemctl restart hostapd
sleep 1
systemctl restart dnsmasq


echo "FabMo-Oriented Network --> RESTARTED/REFRESHED: " $MODE
logger "FabMo-Oriented Network --> RESTARTED/REFRESHED: " $MODE
