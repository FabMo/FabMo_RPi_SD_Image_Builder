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
    apt-get install -y bossa-cli hostapd dnsmasq xserver-xorg-input-libinput pi-package jackd2 python3-pyudev python3-tornado wvkbd
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

    # Bookworm version ... dealing with initialization screens
    echo "Setting up screens ..."
    if ! grep -q "^disable_splash=1" /boot/firmware/config.txt; then
        echo "disable_splash=1" >> /boot/firmware/config.txt
    fi
    if ! grep -q "quiet" /boot/firmware/cmdline.txt; then
        sed -i '1 s/$/ quiet/' /boot/firmware/cmdline.txt
    fi
    if ! grep -q "splash" /boot/firmware/cmdline.txt; then
        sed -i '1 s/$/ splash/' /boot/firmware/cmdline.txt
    fi

    # to get the firstboot expansion to run on the next boot; also a line in the config.txt for this that must be in place
    if ! grep -q "init=/usr/lib/raspberrypi-sys-mods/firstboot" /boot/firmware/cmdline.txt; then
        sed -i'' -e '1 s/$/ init=\/usr\/lib\/raspberrypi-sys-mods\/firstboot/' /boot/firmware/cmdline.txt
    fi

    echo "System Configurations set."
    echo ""
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
    
    # User Utilities
    mkdir -p /home/pi/Scripts
    install_file "$RESOURCE_DIR/fabmo.bashrc" "/home/pi/.bashrc"
    install_file "$RESOURCE_DIR/dev-build.sh" "/home/pi/Scripts"

    # Key USB symlink file for FabMo-G2 and VFD USB devices
    install_file "$RESOURCE_DIR/99-fabmo-usb.rules" "/etc/udev/rules.d/"
    chmod 644 /etc/udev/rules.d/99-fabmo-usb.rules

    # Boot and User Interface Resources
    install_file "$RESOURCE_DIR/FabMo-Icon-03-left.png" "/usr/share/plymouth/themes/pix/splash.png"
    install_file "$RESOURCE_DIR/shopbot-pi-bkgnd.png" "/home/pi/Pictures/shopbot-pi-bkgnd.png"
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "/home/pi/Pictures/FabMo-Icon-03.png"
    install_file "$RESOURCE_DIR/icon.png" "/home/pi/Pictures/icon.png"
    install_file "$RESOURCE_DIR/ShopBot-Desktop-Icon-Transparent.png" "/home/pi/Pictures/ShopBot-Desktop-Icon-Transparent.png"
    plymouth-set-default-theme --rebuild-initrd pix
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
    echo "cloning fabmo-engine"
    git clone https://github.com/FabMo/FabMo-Engine.git /fabmo
    cd /fabmo
    echo "installing fabmo-engine"
    npm install
    echo "building fabmo-engine"
    npm run build 

    echo "cloning fabmo-updater"
    git clone https://github.com/FabMo/FabMo-Updater.git /fabmo-updater
    cd /fabmo-updater
    sudo git status
    sudo git checkout a7c0b35d5e2a53b178ce9b225c62e8012396ec6d
    sudo git status
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
make_misc_tool_symlinks () {
    # hostapd configuration file (will not be updated with fabmo update)
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
    systemctl enable hostapd
    # Key dnsmasq configuration file (will not be updated with fabmo update)
    install_file "$RESOURCE_DIR/dnsmasq/dnsmasq.conf" "/etc/dnsmasq.conf"
    # Make sure we have the right permissions on this file, it is sensitive
    chmod 755 /etc/dnsmasq.conf

    # Install setup-wlan0_ap service file, shell file now in fabmo/files/network_conf_fabmo
    install_file "$FABMO_RESOURCE_DIR/network_conf_fabmo/setup-wlan0_ap.service" "/lib/systemd/system/setup-wlan0_ap.service"

    # enable all of these them
    systemctl daemon-reload
    systemctl enable setup-wlan0_ap
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
    SERVICES=("network-monitor.service" "export-netcfg-thumbdrive.service" "export-netcfg-thumbdrive.path")
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

    echo "BUILD, Installation, and Configuration Complete. ==============(remove BUILD files?)===="
    echo ""
    echo ""
    echo "MANUAL STEPS NOW REQUIRED:"
    echo "-Check to make sure expansion call is in /boot/firmware/cmdline.txt; last line should have init=/usr/lib/raspberrypi-sys-mods/firstboot"
    echo "-Enable running from desktop in FileManager > Edit > Prefs (Don't ask options ...)."
    echo "-Delete this script and /resources from Scripts folder."
    echo "-? Set up rotation for small screen."
    echo ""
    echo "-MAKE 8G COPY NOW, BEFORE FIRST BOOT"
    echo ""
    echo ""
}

# Execute main installation function 
main_installation
