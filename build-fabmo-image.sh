#!/bin/bash -e

# Variables
RESOURCE_DIR="/home/pi/Scripts/resources"
FABMO_RESOURCE_DIR="/fabmo/files"

# Clean any existing install
clean() {
    rm -rf /fabmo
    rm -rf /fabmo-updater
    rm -rf /opt/fabmo
    rm -rf /opt/fabmo_backup
    rm -rf /opt/fabmo_backup_atStart
}

# Function to wait for the dpkg lock to be released
wait_for_dpkg_lock() {
    while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Waiting for dpkg lock to be released..."
        sleep 5
    done
}

copy_files() {
    echo "Copying files from $1 to $2..."
    mkdir -p "$2"
    cp -r "$1"/* "$2"
    echo "Files copied from $1 to $2"
}

# Function to handle simple file operations
install_file() {
    echo "Installing $1 to $2..."
    mkdir -p "$(dirname "$2")"
    cp $1 $2
    echo "Installed $1 to $2"
}

# Install required packages and configure system
install_packages_and_configure() {
    wait_for_dpkg_lock
    echo "Updating package lists..."
    apt-get update
    apt-get install -y bossa-cli hostapd dnsmasq xserver-xorg-input-libinput pi-package jackd2 python3-pyudev python3-tornado wvkbd dos2unix plymouth plymouth-themes
    # Preconfigure jackd2 (audio) to allow real-time process priority
    debconf-set-selections <<< "jackd2 jackd/tweak_rt_limits boolean true"
    echo "Packages installed."
    echo ""
}

# Setup System Configuration (country also done is basic first start of OS download)
setup_system() {
    wait_for_dpkg_lock
    echo "Setting up system configurations..."
    raspi-config nonint do_blanking 1
    raspi-config nonint do_wifi_country US
    raspi-config nonint do_rgpio 0
    raspi-config nonint do_i2c 0
    raspi-config nonint do_ssh 0
    raspi-config nonint do_hostname shopbot

    # Set up node.js
    echo "Installing node.js..."
    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes --batch -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
    wait_for_dpkg_lock
    apt-get update
    apt-get install -y nodejs

    echo "Installing npm..."
    wait_for_dpkg_lock
    apt-get install -y npm
    echo "npm installed."

    # Bookworm version ... dealing with initialization screens for clean boot on RPi 5
    echo "Setting up screens for clean boot experience (RPi 5 optimized)..."
    
    # Configure config.txt for RPi 5 clean boot - especially for cold boot (power-on)
    # RPi 5 requires different splash handling - disable the rainbow splash
    if ! grep -q "^disable_fw_kms_setup=1" /boot/firmware/config.txt; then
        echo "disable_fw_kms_setup=1" >> /boot/firmware/config.txt
    fi
    # Disable the firmware splash screen (critical for cold boot)
    if ! grep -q "^disable_splash=1" /boot/firmware/config.txt; then
        echo "disable_splash=1" >> /boot/firmware/config.txt
    fi
    # Minimize boot delay to start kernel/Plymouth faster
    if ! grep -q "^boot_delay=0" /boot/firmware/config.txt; then
        echo "boot_delay=0" >> /boot/firmware/config.txt
    fi
    # Disable overscan black borders
    if ! grep -q "^disable_overscan=1" /boot/firmware/config.txt; then
        echo "disable_overscan=1" >> /boot/firmware/config.txt
    fi
    # Disable firmware warnings overlay
    if ! grep -q "^avoid_warnings=1" /boot/firmware/config.txt; then
        echo "avoid_warnings=1" >> /boot/firmware/config.txt
    fi
    
    # Add comprehensive boot parameters for clean display on RPi 5
    # Remove any existing quiet/splash/loglevel params first to avoid duplicates
    sed -i'' -e 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g; s/ consoleblank=[0-9]//g' /boot/firmware/cmdline.txt
    
    # Add all boot parameters for suppressing console messages and showing Plymouth splash
    # For clean boot with reasonable error visibility
    if ! grep -q "quiet" /boot/firmware/cmdline.txt; then
        sed -i '1 s/$/ quiet loglevel=3 logo.nologo vt.global_cursor_default=0 console=tty3 splash plymouth.ignore-serial-consoles/' /boot/firmware/cmdline.txt
    fi

    # to get the firstboot expansion to run on the next boot; also a line in the config.txt for this that must be in place
    if ! grep -q "init=/usr/lib/raspberrypi-sys-mods/firstboot" /boot/firmware/cmdline.txt; then
        sed -i'' -e '1 s/$/ init=\/usr\/lib\/raspberrypi-sys-mods\/firstboot/' /boot/firmware/cmdline.txt
    fi
    
    # CRITICAL: Create a boot parameter enforcement script
    # The firstboot script and other processes can strip our parameters
    cat > /usr/local/bin/ensure-fabmo-boot-params.sh <<'EOF'
#!/bin/bash
# Ensure FabMo boot display parameters are always present

CMDLINE_FILE="/boot/firmware/cmdline.txt"
REQUIRED_PARAMS="quiet loglevel=3 logo.nologo vt.global_cursor_default=0 console=tty3 splash plymouth.ignore-serial-consoles"

# Read current cmdline
CURRENT=$(cat "$CMDLINE_FILE")

# Check if all required params are present
NEEDS_UPDATE=0
for PARAM in $REQUIRED_PARAMS; do
    if [[ ! "$CURRENT" =~ $PARAM ]]; then
        NEEDS_UPDATE=1
        break
    fi
done

# Update if needed
if [ $NEEDS_UPDATE -eq 1 ]; then
    echo "FabMo boot parameters missing, restoring..."
    # Remove any existing instances first to avoid duplicates
    sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g' "$CMDLINE_FILE"
    # Add them back
    sed -i "1 s/\$/ $REQUIRED_PARAMS/" "$CMDLINE_FILE"
    echo "Boot parameters restored."
    # Ensure initramfs is current
    update-initramfs -u -k all
fi
EOF
    
    chmod +x /usr/local/bin/ensure-fabmo-boot-params.sh
    
    # Create a systemd service that runs EARLY and on every boot
    cat > /etc/systemd/system/fabmo-boot-params.service <<EOF
[Unit]
Description=Ensure FabMo Boot Display Parameters
DefaultDependencies=no
After=local-fs.target
Before=plymouth-start.service systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ensure-fabmo-boot-params.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF
    
    systemctl enable fabmo-boot-params.service

    echo "System Configurations set."
    echo ""
    
    # NOTE: EEPROM settings (like NET_INSTALL_AT_POWER_ON) are stored in the board's
    # hardware, not on the SD card. They must be configured per-board after flashing.
    # See post-installation notes for RPi 5 EEPROM configuration if needed.
}

# Copy all network, user utility, and system files
copy_all_files() {
    echo "Copying network, user utility, and system files..."
    # NetworkManager Configurations (will not be updated with fabmo update)
    install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf"
    # NetworkManager system-connections (will not be updated with fabmo update)
    copy_files "$RESOURCE_DIR/NetworkManager/system-connections" "/etc/NetworkManager/system-connections"
    # NetworkManager make sure we have the right permissions on these files, they are sensitive
    chmod 600 /etc/NetworkManager/system-connections/*
    
    # NetworkManager dispatcher for automatic AP channel syncing
    mkdir -p /etc/NetworkManager/dispatcher.d
    if [ -d "$RESOURCE_DIR/NetworkManager/dispatcher.d" ]; then
        copy_files "$RESOURCE_DIR/NetworkManager/dispatcher.d" "/etc/NetworkManager/dispatcher.d"
        chmod 755 /etc/NetworkManager/dispatcher.d/*
        echo "Installed NetworkManager dispatcher scripts"
    fi
    
    # User Utilities
    mkdir -p /home/pi/Scripts
    install_file "$RESOURCE_DIR/fabmo.bashrc" "/home/pi/.bashrc"
    install_file "$RESOURCE_DIR/dev-build.sh" "/home/pi/Scripts"
    install_file "$RESOURCE_DIR/cleanup-build.sh" "/home/pi/Scripts"
    chmod +x /home/pi/Scripts/cleanup-build.sh
    install_file "$RESOURCE_DIR/check-boot-config.sh" "/home/pi/Scripts"
    chmod +x /home/pi/Scripts/check-boot-config.sh
    install_file "$RESOURCE_DIR/fix-boot-display-rpi5.sh" "/home/pi/Scripts"
    chmod +x /home/pi/Scripts/fix-boot-display-rpi5.sh
    install_file "$RESOURCE_DIR/fix-cold-boot-and-login.sh" "/home/pi/Scripts"
    chmod +x /home/pi/Scripts/fix-cold-boot-and-login.sh
    install_file "$RESOURCE_DIR/quick-fix-cold-boot.sh" "/home/pi/Scripts"
    chmod +x /home/pi/Scripts/quick-fix-cold-boot.sh

    # Key USB symlink file for FabMo-G2 and VFD USB devices
    install_file "$RESOURCE_DIR/99-fabmo-usb.rules" "/etc/udev/rules.d/"
    chmod 644 /etc/udev/rules.d/99-fabmo-usb.rules

    # Boot and User Interface Resources
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "/usr/share/plymouth/themes/pix/splash.png"
    install_file "$RESOURCE_DIR/shopbot-pi-bkgnd.png" "/home/pi/Pictures/shopbot-pi-bkgnd.png"
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "/home/pi/Pictures/FabMo-Icon-03.png"
    install_file "$RESOURCE_DIR/icon.png" "/home/pi/Pictures/icon.png"
    
    # Configure Plymouth for longer splash display and smooth boot
    # First set the theme
    plymouth-set-default-theme pix
    
    # Configure Plymouth to show splash longer and suppress messages
    mkdir -p /etc/plymouth
    cat > /etc/plymouth/plymouthd.conf <<EOF
[Daemon]
Theme=pix
ShowDelay=0
DeviceTimeout=30
EOF
    
    # Create systemd service to hold Plymouth visible longer during boot
    cat > /etc/systemd/system/plymouth-wait.service <<EOF
[Unit]
Description=Keep Plymouth Splash Visible
DefaultDependencies=no
After=plymouth-start.service
Before=plymouth-quit.service display-manager.service

[Service]
Type=oneshot
ExecStart=/bin/sleep 3
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF
    
    systemctl enable plymouth-wait.service
    
    # Ensure auto-login is configured (don't mask getty, it breaks auto-login)
    # Configure LightDM for auto-login as user pi
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/22-autologin.conf <<EOF
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
EOF
    
    # Ensure Plymouth takes priority over console
    # Modify getty to not clear screen and delay start
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Unit]
# Start getty late, after Plymouth has had time to display
After=plymouth-quit-wait.service

[Service]
# Don't clear the screen
TTYVTDisallocate=no
EOF
    
    # Rebuild initramfs to apply Plymouth changes - do this AFTER all Plymouth config
    update-initramfs -u -k all
    
    install_file "$RESOURCE_DIR/fabmo-release.txt" "/boot"
    install_file "$RESOURCE_DIR/fabmo-release.txt" "/etc"

    # Install the wf-panel-pi.ini to get some panel items in the menu
    install_file "$RESOURCE_DIR/wf-panel-pi.ini" "/home/pi/.config/wf-panel-pi.ini"

    # New virtual keyboard for Bookworm and toggling it on and off
    install_file "$RESOURCE_DIR/toggle-wvkbd.sh" "/usr/bin/toggle-wvkbd.sh"
    install_file "$RESOURCE_DIR/virtual-keyboard.desktop" "/home/pi/.local/share/applications/virtual-keyboard.desktop"
    chmod +x /usr/bin/toggle-wvkbd.sh
    chmod +x /home/pi/.local/share/applications/virtual-keyboard.desktop

    echo "Network, user utility, and system files copied."
    echo ""
}

# Set up desktop for FabMo users 
setup_desktop_environment() { 
    echo "Setting up desktop environment..."
    mkdir -p /home/pi/.config/pcmanfm/LXDE-pi 
    mkdir -p /home/pi/Desktop 
    mkdir -p /etc/X11/xorg.conf.d 
    # Copy configuration files  
    cp $RESOURCE_DIR/desktop-items-0.conf /etc/xdg/pcmanfm/LXDE-pi/ 
    cp $RESOURCE_DIR/panel /etc/xdg/lxpanel/LXDE-pi/panels/ 
    cp $RESOURCE_DIR/40-libinput.conf /etc/X11/xorg.conf.d/ 
    echo "Desktop environment set up."
    echo ""
}

# MAIN Setup FabMo // Note that many resource files are in the fabmo/files directory; so we need to do the MAIN installation before further setup
# ... this is partly done to keep changes in the fabmo update rather than the image
setup_fabmo() {
    # Ensure git respects LF line endings
    git config --global core.autocrlf input

    echo "cloning fabmo-def"
    git clone https://github.com/FabMo/fabmo-def.git /fabmo-def
    echo "done fabmo-def"

    echo "cloning fabmo-engine"
    git clone https://github.com/FabMo/FabMo-Engine.git /fabmo
    cd /fabmo
    echo "installing fabmo-engine"
    npm install
    echo "building fabmo-engine"
    npm run build 

    # Verify and fix line endings for shell scripts
    echo "Ensuring LF line endings for shell scripts..."
    find /fabmo/files -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true
    find /fabmo/files/network_conf_fabmo -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true

    echo "cloning fabmo-updater"
    git clone https://github.com/FabMo/FabMo-Updater.git /fabmo-updater
    cd /fabmo-updater
    npm install

    # OBSOLETE but a repeated boot is still needed to get everything in place and running
    # The updater needs to be started twice to create config files and run
    #npm run start
    # Delay to allow the updater to create the config files
    #sleep 15
    #npm run start
    
    echo "installed fabmo-updater"

    echo "FabMo and Updater done ..."
    echo ""
}

#------------------------------------------------------------------------------------------------------------------------------------
## CONTENT FROM fabmo and fabmo-updater NOW AVAILABLE in the install process 
#------------------------------------------------------------------------------------------------------------------------------------

# Move files from fabmo/files to the correct locations and set permissions **BUT CURRENT VERSIONS NEED TO BE IN PLACE FIRST in fabmo/files !
# ... this is done to keep as much as reasonable in the fabmo update rather than the image 
# ... this is done after fabmo is installed to prevent changes to the fabmo update from being copied to the image
# install hostapd service file and other symlinks
# NOTE THAT hostapd and dnsmasq are still managed from here and not in the fabmo update:
#                                                                            /resources/dnsmasq/
#                                                                                         dnsmasq.conf
#                                                                            /resources/hostapd/
#                                                                                         hostapd.conf
#                                                                                         hostapd.service
# IMPORTANT: The hostapd service is DISABLED because NetworkManager manages the AP via wlan0_ap connection.
#            The config files are installed for reference/fallback but standalone hostapd should not run.
make_misc_tool_symlinks () {
    # hostapd configuration file (will not be updated with fabmo update)
    # NOTE: This is a fallback config - NetworkManager manages the actual AP
    mkdir -p /etc/hostapd
    install_file "$RESOURCE_DIR/hostapd/hostapd.conf" "/etc/hostapd/hostapd.conf"
    install_file "$RESOURCE_DIR/hostapd/hostapd.service" "/lib/systemd/system/hostapd.service"
    chmod -x /lib/systemd/system/hostapd.service
    # Create the directory for hostapd PID file
    mkdir -p /run/hostapd
    chown root:root /run/hostapd
    chmod 755 /run/hostapd
    systemctl unmask hostapd
    systemctl daemon-reload
    # NOTE: hostapd should NOT be enabled when NetworkManager manages the AP
    # NetworkManager uses its own internal hostapd for the wlan0_ap connection
    # Enabling standalone hostapd causes conflicts with the SSID not updating
    systemctl disable hostapd

    # Key dnsmasq configuration files (will not be updated with fabmo update)
    install_file "$RESOURCE_DIR/dnsmasq/dnsmasq.conf" "/etc/dnsmasq.conf"
    chmod 755 /etc/dnsmasq.conf
    
    # Create dnsmasq.d directory if it doesn't exist
    mkdir -p /etc/dnsmasq.d
    chmod 755 /etc/dnsmasq.d
    
    # Install mode-specific dnsmasq configurations
    install_file "$RESOURCE_DIR/dnsmasq/ap-only.conf" "/etc/dnsmasq.d/ap-only.conf"
    install_file "$RESOURCE_DIR/dnsmasq/direct-mode.conf" "/etc/dnsmasq.d/direct-mode.conf"
    chmod 644 /etc/dnsmasq.d/ap-only.conf
    chmod 644 /etc/dnsmasq.d/direct-mode.conf
    
    # Set initial mode to ap-only (safer default - won't serve DHCP on LAN)
    ln -sf /etc/dnsmasq.d/ap-only.conf /etc/dnsmasq.d/active-mode.conf
    
    # enable all of these them
    systemctl daemon-reload
    systemctl enable dnsmasq
    
# Create Sym-links for External FabMo Tools services
    sudo ln -sf $FABMO_RESOURCE_DIR/tools/ck_heat_volts.sh /usr/local/bin/ck_heat_volts
    sudo ln -sf $FABMO_RESOURCE_DIR/tools/ck_network.sh /usr/local/bin/ck_network
    sudo ln -sf $FABMO_RESOURCE_DIR/tools/ck_services.sh /usr/local/bin/ck_services
    sudo ln -sf $FABMO_RESOURCE_DIR/tools/ld_firmware.sh /usr/local/bin/ld_firmware
}

# SystemD
load_and_initialize_systemd_services() {
    echo "Setting up systemd services..."

    # FabMo and Updater SystemD Service symlinks to files
    cd /etc/systemd/system

    echo "Creating systemd sym-links for listed files in fabmo/files ..."
    SERVICES=("fabmo.service" "camera-server-1.service" "camera-server-2.service" "usb_logger.service")
    # Loop through the services and create symlinks
    for SERVICE in "${SERVICES[@]}"; do
        if [ -f "/fabmo/files/$SERVICE" ]; then
            if [ ! -L "/etc/systemd/system/$SERVICE" ]; then
                ln -s "/fabmo/files/$SERVICE" .
                echo "Created symlink for /fabmo/files/$SERVICE"
            else
                echo "Symlink for /fabmo/files/$SERVICE already exists"
            fi
        else
            echo "Source file /fabmo/files/$SERVICE does not exist"
        fi
    done    
    
    echo "Creating systemd sym-links listed files in fabmo/files/network_conf_fabmo ..."
    SERVICES=("network-monitor.service" "setup_wlan0_ap.service" "export-netcfg-thumbdrive.service" "export-netcfg-thumbdrive.path")
    for SERVICE in "${SERVICES[@]}"; do
        if [ -f "/fabmo/files/network_conf_fabmo/$SERVICE" ]; then
            if [ ! -L "/etc/systemd/system/$SERVICE" ]; then
                ln -s "/fabmo/files/network_conf_fabmo/$SERVICE" .
                echo "Created symlink for /fabmo/files/network_conf_fabmo/$SERVICE"
            else
                echo "Symlink for /fabmo/files/network_conf_fabmo/$SERVICE already exists"
            fi
        else
            echo "Source file /fabmo/files/network_conf_fabmo/$SERVICE does not exist"
        fi
    done
    
    echo "Copy the recent_wifi.json from /fabmo/files/network_conf_fabmo to /etc/network_conf_fabmo" 
    mkdir -p /etc/network_conf_fabmo
    install_file "$FABMO_RESOURCE_DIR/network_conf_fabmo/recent_wifi.json" "/etc/network_conf_fabmo/recent_wifi.json"
    echo "... done created /etc/network_conf_fabmo/recent_wifi.json"

    echo "Creating systemd sym-links from fabmo-updater ..."
    SERVICES=("fabmo-updater.service")
    for SERVICE in "${SERVICES[@]}"; do
        if [ -f "/fabmo-updater/files/$SERVICE" ]; then
            if [ ! -L "/etc/systemd/system/$SERVICE" ]; then
                ln -s "/fabmo-updater/files/$SERVICE" .
                echo "Created symlink for /fabmo-updater/files/$SERVICE"
            else
                echo "Symlink for /fabmo-updater/files/$SERVICE already exists"
            fi
        else
            echo "Source file /fabmo-updater/files/$SERVICE does not exist"
        fi
    done
    
    # Create or edit the systemd override for dnsmasq
    mkdir -p /etc/systemd/system/dnsmasq.service.d
    sudo tee /etc/systemd/system/dnsmasq.service.d/override.conf > /dev/null <<EOF
    [Unit]
    After=network-online.target
    Wants=network-online.target
EOF
    # Install autostart for ip-reporting, method should work for generic user in bookworm 
    install_file "/fabmo/files/network_conf_fabmo/fabmo-ip-reporting.desktop" "/etc/xdg/autostart/fabmo-ip-reporting.desktop"
    chmod -x /etc/xdg/autostart/fabmo-ip-reporting.desktop
    
    # Make sure that all files in /fabmo/files and subdirectories that end in .service or .path are not executable
    find /fabmo/files -type f -name "*.service" -exec chmod -x {} \;
    find /fabmo-updater/files -type f -name "*.service" -exec chmod -x {} \;
    find /fabmo/files/network_conf_fabmo -type f -name "*.service" -exec chmod -x {} \;
    find /fabmo/files/network_conf_fabmo -type f -name "*.path" -exec chmod -x {} \;

     # Make sure that all files in /fabmo/files and subdirectories that end in .sh or .py are executable
    find /fabmo/files -type f -name "*.sh" -exec chmod +x {} \;
    find /fabmo/files/network_conf_fabmo -type f -name "*.sh" -exec chmod +x {} \;
    find /fabmo/files/tools -type f -name "*.sh" -exec chmod +x {} \;
    find /fabmo/files -type f -name "*.py" -exec chmod +x {} \;
    find /fabmo/files/network_conf_fabmo -type f -name "*.py" -exec chmod +x {} \;
    find /fabmo/files/tools -type f -name "*.py" -exec chmod +x {} \;

    echo "Enabling systemd services..."
    systemctl daemon-reload
    systemctl enable fabmo.service
    systemctl enable fabmo-updater.service
    systemctl enable network-monitor.service
    # NOTE: setup_wlan0_ap.service is NOT enabled at boot - it's only called by ip-reporting.py
    # when the SSID needs to be updated. NetworkManager auto-connects wlan0_ap on boot.
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable usb_logger.service

    echo "Systemd services setup complete."
    echo ""
}

some_extras () {
    # Install a ShopBot starter on Desktop; may work, requires the setting fix in RPi File Manager to not ask options on launch executable file.
    install_file "$RESOURCE_DIR/shopbot-starter.desktop" "/home/pi/Desktop/shopbot-starter.desktop"
    chmod +x /home/pi/Desktop/shopbot-starter.desktop
}


# Main installation
main_installation() {
    echo ""
    echo "BUILDING FabMo SD-Card IMAGE ==========================================================="
    echo ""
    clean
    install_packages_and_configure
    setup_system
    copy_all_files
    setup_desktop_environment
    setup_fabmo
    cd /home/pi
    load_and_initialize_systemd_services
    make_misc_tool_symlinks 
    some_extras

    echo ""
    echo "BUILD, Installation, and Configuration Complete. ============================================"
    echo ""
    echo ""
    echo "MANUAL STEPS NOW REQUIRED:"
    echo "1. Verify boot configuration: /home/pi/Scripts/check-boot-config.sh"
    echo "2. Run cleanup script: sudo /home/pi/Scripts/cleanup-build.sh"
    echo "   (Removes build files, resources, and temp repo)"
    echo "3. UI Adjustments:"
    echo "   - Set Task Bar: bottom, medium size"
    echo "   - Set Desktop text color to #353A92 (dark blue)"
    echo "   - Add RPI-CONNECT to Menu Bar"
    echo "4. Verify: cat /boot/fabmo-release.txt"
    echo ""
    echo "5. MAKE 16G SD COPY on RPi BEFORE FIRST REBOOT (prevents expansion)"
    echo ""
    echo "NOTE: Boot display optimized for RPi 5 - clean FabMo logo, no scrolling messages"
    echo "      Run check-boot-config.sh to verify all settings"
    echo ""
    echo ""
}

# Execute main installation function 
main_installation
