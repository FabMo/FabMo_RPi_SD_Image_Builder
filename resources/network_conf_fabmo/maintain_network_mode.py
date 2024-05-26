#!/usr/bin/python3

import time
from datetime import datetime
import os
import subprocess
import syslog
import hashlib

# This script is intended to be run as a service for the FabMo controller.
# The idea is to set networking for either Server or Client mode, to make the ethernet connection (if one exits)
# have the RP sever as a DHCP Client in the case of a LAN connectiona and as a DHCP server for a direct PC connection.
# automatically switch to the desired mode after a period of stability.
# This script will run in a loop, checking the desired network mode every 30 seconds.
# If the desired network mode has changed, then the script will check to see if the file has been stable for 10 seconds.
# If a change has been stable for 10 seconds, then change the network mode to match the new desired mode.

cycle_sleep = 30
stabilization_period = 10

current_network_conf_file="/etc/network_conf_fabmo/current_network_mode.conf"
desired_network_conf_file="/etc/network_conf_fabmo/desired_network_mode.conf"

chooseServer = "/etc/network_conf_fabmo/assigns_ip_addresses/chooseMe.sh"
chooseClient = "/etc/network_conf_fabmo/asks_for_ip_address/chooseMe.sh"
chooseStatic = "/etc/network_conf_fabmo/configured_static_ip/chooseMe.sh"

def getModeFromFile(file):
    try:
        with open(file) as config_file:
            line = config_file.readline()
        return line
    except IOError as e:
        print(f"Error reading file {file}: {e}")
        return None  # or handle the error as needed

def changeNetworkMode(desiredMode, currentMode):
    try:
        if("Server" in desiredMode):
            print("choosing server")
            subprocess.run([chooseServer])
        elif("Client" in desiredMode):
            print("choosing client")
            subprocess.run([chooseClient])
        elif("Static" in desiredMode):
            print("choosing static")
            subprocess.run([chooseStatic])
        else:
            print("ERROR - Mode not supported!")
            print("current: " + currentMode)
            print("desired: " + desiredMode)
            return
        subprocess.run(["/usr/bin/cp", desired_network_conf_file, current_network_conf_file])
    except subprocess.SubprocessError as e:
        print(f"Error executing subprocess for {desiredMode}: {e}")

def updateNetworkModeIfNeeded():
    syslog.syslog("###=> Check Network Mode ...")
    currentMode = getModeFromFile(current_network_conf_file)
    desiredMode = getModeFromFile(desired_network_conf_file)

    print("current: " + currentMode)
    print("desired: " + desiredMode)

    if (currentMode == desiredMode):
        print("No changes needed.")
        return
    else:
        print("Changing Newwork Mode.")
        syslog.syslog("###=> Changing Network Mode!")
        changeNetworkMode(desiredMode, currentMode)


# run once to sync everything up in OS
currentMode = getModeFromFile(current_network_conf_file)
desiredMode = getModeFromFile(desired_network_conf_file)
changeNetworkMode(desiredMode, currentMode)

def hash_file(filepath):
    with open(filepath, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()

last_hash = None
last_change_time = None

while True:
    print("Checking Network Type @30s")
    print(f"Loop start: {datetime.now()}")
    now = time.time()

    current_hash = hash_file(desired_network_conf_file)

    if current_hash != last_hash:
        last_hash = current_hash
        last_change_time = now
    elif now - last_change_time > stabilization_period:
        print(f"File content stable for more than {stabilization_period} seconds. Checking ...")
        updateNetworkModeIfNeeded()
    else:
        print("File content changed recently. Waiting to stabilize.")

    print(f"Sleeping for {cycle_sleep} seconds @ {datetime.now()}\n")
    time.sleep(cycle_sleep)
    print(f"Woke up @ {datetime.now()}")

# while True:
#     print("Checking Network Type @30s")
#     print(f"Loop start: {datetime.now()}")
#     now = time.time()

#     fileModTime = os.path.getmtime(desired_network_conf_file)

#     print("fileModTime: ", fileModTime)
#     print("now: ", now)

#     if (now - fileModTime) > stabilization_period:
#         print(f"File mod older than than {stabilization_period} seconds. Checking ...")
        
#         updateNetworkModeIfNeeded()
#     else:
#         print("File mod too recent. Waiting to stabilize.")

#     print(f"Sleeping for {cycle_sleep} seconds @ {datetime.now()}\n")
#     time.sleep(cycle_sleep)
#     print(f"Woke up @ {datetime.now()}") 