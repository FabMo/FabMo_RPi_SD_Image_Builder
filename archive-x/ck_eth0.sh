#!/bin/bash

# Specify the Ethernet interface, e.g., eth0
INTERFACE="eth0"

# Set a timeout for how long dhclient should try to get an IP address (in seconds)
TIMEOUT=20

# Attempt to get an IP address from a DHCP server with a timeout
sudo dhclient -v $INTERFACE &> /tmp/dhclient_output.txt

#RESULT = sudo dhclient -v interface check=True text=True capture_output=True
#echo $RESULT



# Check if dhclient was successful by looking for a DHCPACK in the output
if grep -q "DHCPACK" /tmp/dhclient_output.txt; then
  echo "DHCP server detected (eth0)."
  # Perform actions for when connected to a network with a DHCP server
else
  echo "No DHCP server detected (eth0)."
  # Perform actions for when directly connected to a PC without a DHCP server
fi

# Clean up: release the IP address obtained via DHCP
sudo dhclient -r $INTERFACE

# Optionally, remove the temporary file
#rm /tmp/dhclient_output.txt
