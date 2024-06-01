#!/usr/bin/python3

import tkinter as tk
import subprocess
import syslog
import time
import json
#import os
import subprocess

# Monitor the tool's connections every 10s -- 
#     If we get a change in -MODE- of wired connection mode (ethernet or direct)
#       then> a) write the new desired MODE to "/etc/network_conf_fabmo/desired_network_mode.conf" 
#                (monitored by "/etc/network_conf_fabmo/maintain_network_mode.py", which will re-write dhcp_conf, etc)
#     If we get a new -connection/interface- of a higher priority than current ( with: eth > wifi > ap )
#       then> 1) change the title of the display window
#             2) change the displayed IP as it becomes available
#             3) change the ssid name of the AP display (uap0) to provide info to the user's device
#             4) restart hostapd (and anything else required) to effect and cleanup the name change

syslog.syslog('###=> Launching IP Address Display App ... (in 10sec)')
time.sleep(10)  # Wait for 10 seconds for network to stabilize before starting

#-------------------------------------------Initialize wifi/AP at full power
cmd = "sudo /sbin/iwconfig wlan0 power off"
result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, shell=True)
output = result.stdout
cmd = "sudo /sbin/iw dev uap0 set power_save off"
result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, shell=True)
output = result.stdout

class NetworkConfigApp:
    def __init__(self, config_file, state_file):
        self.config_file = config_file
        self.state_file = state_file
        self.config_value = ""
        self.name = "FabMo-# AP@:192.168.42.1"
        self.tool_name = "FabMo-####" 
        self.last_name = ""
        self.last_ssid = ""
        self.last_ip_address_wifi = ""
        self.name_file = "/opt/fabmo/config/engine.json"
        self.initialize_ui()
    #    self.update_radio_buttons()        # Call once setting default or initial state
        print("###===> Starting IP Address Display App ...")
        self.update_ip_display()           # START

    # ------------------------------------------------------------- Setup Tkinter UI 
    def initialize_ui(self):
        self.root = tk.Tk()

        # Set window temporarily on top
        self.root.focus_set()
        self.root.attributes("-topmost", True)
        frame = tk.Frame(self.root)
        frame.pack(padx=10, pady=10)
        self.ip_var = tk.StringVar()
        ip_label = tk.Label(frame, textvariable=self.ip_var, font=("Arial", 18))
        ip_label.pack(pady=5)

        # Set the window position to top right corner
        screen_width = self.root.winfo_screenwidth()
        window_width = 500
        x_position = screen_width - window_width -50
        self.root.geometry(f"{window_width}x200+{x_position}+100")

        # Create the label explaining the use of the IP address
        mode_label1 = tk.Label(frame, text="Enter this address in your browser\nto access the tool.", font=("Arial", 16))
        mode_label1.pack(pady=5)

        mode_label2 = tk.Label(frame, text="(If you choose to access the tool from the small screen,\nit is easiest with a mouse attached.)", font=("Arial", 12))
        mode_label2.pack(pady=5)
        # # Initialize StringVar for radio buttons
        # self.net_mode_var = tk.StringVar()

        # # Define the ratio button options
        # net_modes = (("ethernet to network (LAN)", "DHCP Client"), ("ethernet directly to PC", "DHCP Server"))

        # # Create the radio buttons
        # for mode_text, mode_value in net_modes:
        #     # Write the new mode if the radio button is clicked!
        #     syslog.syslog(f"###=> Write the new -Desired- Network Mode Value ! >>> {mode_value}")
        #     rb = tk.Radiobutton(frame, text=mode_text, variable=self.net_mode_var, font=("Arial", 14), value=mode_value, command=lambda mode_value=mode_value: self.write_config(mode_value))
        #     rb.pack(anchor=tk.W, padx=10)
    #------------------------------------------------------------- END Setup Tk

    #------------------------------------------------------------- Only read at app start
    # def update_radio_buttons(self):
    #     self.config_value = self.read_config()  
    #     #print(f"###=> Initial 'desired' value: {self.config_value}")
    #     #syslog.syslog(f"###=> Initial 'desired' value: {self.config_value}")
    #     if self.config_value is not None:
    #         self.net_mode_var.set(self.config_value)
    #     else:
    #         print("###===> Did not find 'desired' mode. Defaulting to DHCP Sever")
    #         syslog.syslog("###===> Did not find 'desired' mode. Defaulting to DHCP Sever")
    #         self.net_mode_var.set("DHCP Server")  # Default value if we can't read the file

    def read_config(self):  # Read the "desired" network mode from this file
        try:
            with open(self.config_file, "r") as f:
                desired_mode = f.read().strip()
                # prevent corruptions
                if desired_mode != "DHCP Client" or desired_mode != "DHCP Server":
                    current_state = self.read_state()
                    if current_state == "DHCP Client" or current_state == "DHCP Server":
                        desired_mode = current_state
                    else:
                        desired_mode = "DHCP Client"
            return desired_mode
        except FileNotFoundError:
            print("###===> Trouble with reading desired_network_mode!") 
            return None

    def read_state(self): 
        try:
            with open(self.state_file, "r") as f:
                current_state = f.read().strip()
                return current_state
        except FileNotFoundError:
            print("###===>  Trouble with reading current_network_state!") 
            return None
    #------------------------------------------------------------- END Read at app start  

    def check_dhcp_server(self, interface):
    # Attempt to get an IP address from the DHCP server reflecting an ethernet to LAN connection
        try:
            result = subprocess.run(['sudo', 'dhclient', '-v', interface], check=True, text=True, capture_output=True)
            if "DHCPACK" in result.stderr:
                print("DHCP server detected.")
                return True
            else:
                print("No DHCP server detected.")
                # Clean up: release the IP address obtained via DHCP
                subprocess.run(['sudo', 'dhclient', '-r', interface], check=True)
                return False
        except subprocess.CalledProcessError as e:
            print(f"dhclient encountered an error: {e}")
            return False
        except subprocess.TimeoutExpired as e:
            print(f"dhclient command timed out: {e}")
            return False
        #finally:
            # Clean up: release the IP address obtained via DHCP
            #subprocess.run(['sudo', 'dhclient', '-r', interface], check=True)

    def read_tool_name(self):
    # Read tool name from fabmo config; ssid is limited to 32 char; so tool_name limited to 12 char should work 
        try:
            with open(self.name_file, "r") as f:
                data = json.load(f)
                self.tool_name = data.get('name', 'no-name').strip()
                if len(self.tool_name) > 12:
                    self.tool_name = self.tool_name[:12]
                return self.tool_name
        except FileNotFoundError:
            print("###=== X Trouble with reading tool_name!")
            syslog.syslog("###=== X Trouble with reading tool_name!") 
            return "no-name"
    
    def get_ip_address(self, interface='wlan0', retries=3, delay=4):
        # Use ip to extract the IP address of wlan0
        cmd = f"ip addr show {interface} | grep 'inet ' | awk '{{print $2}}' | cut -d/ -f1"
        # May take some time and tries to get the wifi-IP after a renaming-restart, set dhclient.conf to 20sec timeout to improve
        for _ in range(retries):
            try:
                ip_address = subprocess.check_output(cmd, shell=True).decode("utf-8").strip()
                if ip_address:
                    print(f"    => ip-check: {interface}  {ip_address}") 
                    return ip_address
            except subprocess.CalledProcessError:
                pass
            time.sleep(delay)
        print(f"    => failed to find ip - {interface}")
        syslog.syslog(f"    => failed to find ip - {interface}")
        return "None"

    def is_eth0_active(self):
        result = subprocess.run(['ifconfig'], stdout=subprocess.PIPE, text=True)
        output = result.stdout
        for line in output.splitlines():
            if line.startswith('eth0:') and 'RUNNING' in line:
                return True
        return False

    def get_wlan0_ssid(self):
    #    result = subprocess.run(['sudo', 'iw', 'dev', 'wlan0', 'info'], stdout=subprocess.PIPE, text=True, check=True)
        result = subprocess.run(['iw', 'dev', 'wlan0', 'info'], stdout=subprocess.PIPE, text=True, check=True)
        output = result.stdout
        return output

    def parse_ssid(self, output):
        #print(f"###=>wlan: {output}")
        for line in output.split('\n'):
            if 'ssid' in line:
                # syslog.syslog(f"###=======> line: {line}")
                # Assuming the format is "ssid SSIDNAME"
                ssid = line.split(' ', 1)[1].strip()
                syslog.syslog(f"###=====> ssid: {ssid}")
                return ssid
        syslog.syslog(f"###=====> ssid: None")
        return "None"  # Return None or an appropriate value if SSID is not found
        
    def write_config(self, mode=""):
        # Update the desired network mode in the file if we have a new value
        print(f"### --- debug, got Write  > Updating -Desired- file: {mode}")
        if mode != self.config_value:
            self.config_value = mode
            print(f"###= >Updating -Desired- file: {mode}")
            syslog.syslog(f"###=> Updating -Desired- file: {mode}")
            with open(self.config_file, 'w') as f:
                f.write(mode)
            # let user know it will take a bit to update   
            self.ip_var.set("---identifying---")

    def write_wifi_info_to_json(self, wifi_info):
        file_path = "/etc/network_conf_fabmo/recent_wifi.json"
        try:
            with open(file_path, 'w') as json_file:
                json.dump(wifi_info, json_file)
            print(f"WiFi information written to {file_path}")
            syslog.syslog(f"WiFi information written to {file_path}")
        except Exception as e:
            print(f"Failed to write WiFi information to {file_path}: {e}")
            syslog.syslog(f"Failed to write WiFi information to {file_path}: {e}")        


    ## PRIMARY FUNCTION ===============================================================
    def update_ip_display(self):
        syslog.syslog("###=> IP Udate Sequence Starting ...")
        print("###=> IP Udate Sequence Starting ...")

        # Is eth0 a DHCP Client? TRUE means ethernet plugged into LAN and getting address
        #   FALSE means ethernet might be plugged into PC and getting address or not
        #   But, since eth0 is primary we will set networking MODE for this connection if present (RPi as client)
        #   ... and if not, set up network MODE for a direct connection to PC (RPi as server)
        #   ... wifi and AP mode should work with either, with wifi being the 3rd priority for display on device and ssid        
        # if self.check_dhcp_server("eth0"):
        #     print("Ethernet is a DHCP client")
        #     syslog.syslog("Ethernet is a DHCP client")
        #     new_mode = "DHCP Client"
        # else:
        #     print("Ethernet is not a DHCP client")
        #     syslog.syslog("Ethernet is not a DHCP client")
        #     new_mode = "DHCP Server"
        # self.net_mode_var.set(new_mode)   # setting the button does not seem to trigger the same action as user click
        # self.write_config(new_mode)

        # Primary display data
        self.tool_name = self.read_tool_name()
        ip_address = self.get_ip_address("eth0")
        ip_address_wifi = self.get_ip_address("wlan0")
        ip_address_uap0 = self.get_ip_address("uap0")

        # This just info is for fabmo wifi manager display
        ssid = self.parse_ssid(self.get_wlan0_ssid())
        if ssid != "None":
            wifi_info = {
                "ip_address": ip_address_wifi,
                "ssid": ssid
            }
        else:
            wifi_info = {
                "ip_address": "",
                "ssid": ""
            }
        if ssid != self.last_ssid or ip_address_wifi != self.last_ip_address_wifi:    
            self.write_wifi_info_to_json(wifi_info)
            self.last_ip_address_wifi = ip_address_wifi
            self.last_ssid = ssid
            
        # Now see if eth0 is active on either DHCP Client or DHCP Server and whether we have an IP address
        eth = self.is_eth0_active()
        syslog.syslog(f"###=> Checking eth0 = {eth}")
        print(f"###=> Checking eth0 = {eth}")
        syslog.syslog(f"###=> ip_address eth0: {ip_address}")
        print(f"###=> ip_address eth0: {ip_address}")
        # Checking wlan0 ssid
        syslog.syslog(f"###=> wlan0ssid: {ssid}")
        print(f"###=> wlan0ssid: {ssid}")
        syslog.syslog(f"###=> ip_address_wifi: {ip_address_wifi}")
        print(f"###=> ip_address_wifi: {ip_address_wifi}")
        # And, checking uap0 as well
        syslog.syslog(f"###=> ip_address_uap0: {ip_address_uap0}")
        print(f"###=> ip_address_uap0: {ip_address_uap0}")


    # Update UI elements and network actions based on interface presence and IP address
        # Check if eth0 is active interface - FIRST selection priority
        if eth:
            # Check for Direct PC connection
            if ip_address.endswith(".44.1"):
                self.root.title("- Computer 192.168.44.1 - ")
                self.name = self.tool_name + "-PC@192.168.44.1"
                self.ip_var.set("192.168.44.1")
            else:
                self.root.title("- LOCAL NETWORK IP - ")
                self.name = self.tool_name + "-LAN@" + ip_address
                self.ip_var.set(f"{ip_address}")

        # Then check if wlan0 is an active interface - SECOND selection priority
        elif ssid != "None":
            str_title = "- " + ssid + " NETWORK IP - "
            self.root.title(str_title)
            self.name = self.tool_name + "-wifi@" + ip_address_wifi
            self.ip_var.set(f"{ip_address_wifi}")
        else:    

        # If neither eth0 or wlan0 is active, then we only have AP mode
            if ip_address_uap0.endswith(".42.1"):
                self.root.title("- AP Mode IP - ")
                self.name = self.tool_name + "-AP@192.168.42.1"
                self.ip_var.set("192.168.42.1")
            # Or we are not anywhere we understand ...
            else:
                self.root.title("- UNKNOWN NETWORK IP - ")
                self.name = "UNKNOWN@-"
                self.ip_var.set("no-identified-network-ip")

        # NOW, If the name has changed; Update the displayed data in AP-SSID
        if self.last_name != self.name:
            rt = "sudo"
            cmd = "/home/pi/bin/change_ssid.sh"
            subprocess.run([rt, cmd, self.name] ,stdout=subprocess.PIPE, text=True, check=True)
            syslog.syslog(f"###=> Changing AP Name; NewName={self.name} OldName={self.last_name}\n")
            print(f"###=> Changing AP Name; NewName={self.name} OldName={self.last_name}\n")
            time.sleep(5)  # Wait for the name change to take effect

        syslog.syslog(f"###=> name={self.name} last_name={self.last_name}")
        syslog.syslog(f"      ip={ip_address} MODE={self.config_value}")
        print(f"###=> name={self.name} last_name={self.last_name}")
        print(f"      ip={ip_address} MODE={self.config_value}")

    #    self.update_radio_buttons()
        self.last_name = self.name
        self.root.after(5000, self.update_ip_display)  # Schedule next IP update

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    CONFIG_FILE = "/etc/network_conf_fabmo/desired_network_mode.conf"
    STATE_FILE = "/etc/network_conf_fabmo/current_network_mode.conf"
    app = NetworkConfigApp(CONFIG_FILE, STATE_FILE)
    app.run()
