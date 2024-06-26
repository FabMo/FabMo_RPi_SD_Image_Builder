#!/bin/bash -e

# Variables
RESOURCE_DIR="/home/pi/Scripts/resources"

# Clean any existing install
clean() {
    rm -rf /fabmo
    rm -rf /fabmo-updater
    rm -rf /opt/fabmo
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
    apt-get install -y bossa-cli hostapd dnsmasq onboard xserver-xorg-input-libinput pi-package jackd2 python3-pyudev python3-tornado
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
    #raspi-config nonint do_expand_rootfs


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

    # to get the firstboot expansion to run on the next boot; also a line in the config.txt for this
    if ! grep -q "init=/usr/lib/raspberrypi-sys-mods/firstboot" /boot/firmware/cmdline.txt; then
        sed -i'' -e '1 s/$/ init=\/usr\/lib\/raspberrypi-sys-mods\/firstboot/' /boot/firmware/cmdline.txt
    fi

    echo "System Configurations set."
    echo ""
}

# Copy all network, user utility, and system files
copy_all_files() {
    echo "Copying network, user utility, and system files..."
    # NetworkManager Configurations
    install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf"
    # NetworkManager system-connections
    copy_files "$RESOURCE_DIR/NetworkManager/system-connections" "/etc/NetworkManager/system-connections"
    # NetworkManager make sure we have the right permissions on these files, they are sensitive
    chmod 600 /etc/NetworkManager/system-connections/*
    # hostapd configuration file
    mkdir -p /etc/hostapd
    install_file "$RESOURCE_DIR/hostapd/hostapd.conf" "/etc/hostapd/hostapd.conf"
    # install hostapd service file
    install_file "$RESOURCE_DIR/sysd-services/hostapd.service" "/lib/systemd/system/hostapd.service"
    # Create the directory for hostapd PID file
    mkdir -p /run/hostapd
    chown root:root /run/hostapd
    chmod 755 /run/hostapd
    systemctl unmask hostapd
    systemctl daemon-reload
    systemctl enable hostapd
    # Key dnsmasq configuration file
    install_file "$RESOURCE_DIR/dnsmasq/dnsmasq.conf" "/etc/dnsmasq.conf"
    # Make sure we have the right permissions on this file, it is sensitive
    chmod 755 /etc/dnsmasq.conf
    systemctl enable dnsmasq
    # install hostapd service file
    install_file "$RESOURCE_DIR/sysd-services/setup-wlan0_ap.service" "/lib/systemd/system/setup-wlan0_ap.service"

    # Network Monitoring and IP Display Utilities for FabMo along with some usable diagnostic scripts
    mkdir -p /usr/local/bin
    copy_files "$RESOURCE_DIR/usr-local-bin" "/usr/local/bin"
    # Make sure we have the right permissions on these files, they are sensitive
    chmod 755 /usr/local/bin/*
    systemctl daemon-reload
    systemctl enable setup-wlan0_ap

    # User Utilities
    mkdir -p /home/pi/Scripts
    install_file "$RESOURCE_DIR/fabmo.bashrc" "/home/pi/.bashrc"
    install_file "$RESOURCE_DIR/dev-build.sh" "/home/pi/Scripts"

    # Key USB symlink file for FabMo and VFD
    install_file "$RESOURCE_DIR/99-fabmo-usb.rules" "/etc/udev/rules.d/"

    # Boot and User Interface Resources
    install_file "$RESOURCE_DIR/FabMo-Icon-03-left.png" "/usr/share/plymouth/themes/pix/splash.png"
    install_file "$RESOURCE_DIR/shopbot-pi-bkgnd.png" "/home/pi/Pictures/shopbot-pi-bkgnd.png"
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "/home/pi/Pictures/FabMo-Icon-03.png"
    install_file "$RESOURCE_DIR/icon.png" "/home/pi/Pictures/icon.png"
    install_file "$RESOURCE_DIR/xShopBot4.ico" "/home/pi/Pictures/xShopBot4.ico"
    plymouth-set-default-theme --rebuild-initrd pix
    install_file "$RESOURCE_DIR/fabmo_linux_version.txt" "/boot"
    install_file "$RESOURCE_DIR/fabmo-release.txt" "/etc"

    # Install the wf-panel-pi.ini to get some panel items in the menu
    install_file "$RESOURCE_DIR/wf-panel-pi.ini" "/home/pi/.config/wf-panel-pi.ini"

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

# Setup FabMo
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
    npm install
    # The updater needs to be started twice to create config files and run
    npm run start
    # Delay to allow the updater to create the config files
    sleep 15
    #npm run start
    
    echo "installed fabmo-updater"

    echo "FabMo and Updater done ..."
    echo ""
}

# SystemD
load_and_initialize_systemd_services() {
    echo "Setting up systemd services..."

    # FabMo and Updater SystemD Service symlinks to files
    cd /etc/systemd/system
    echo "Creating systemd sym-links from fabmo/files ..."
    SERVICES=("fabmo.service" "camera-server-1.service" "camera-server-2.service")
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
    echo "Creating systemd sym-links from fabmo/files/network_conf_fabmo ..."
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
    
    # Make sure files in /fabmo/files are executable
    chmod +x /fabmo/files/*
    # Make sure files in /fabmo-updater/files are executable
    chmod +x /fabmo-updater/files/*
    # Make sure files in /fabmo/files/network_conf_fabmo are executable
    chmod +x /fabmo/files/network_conf_fabmo/*    

    echo "Enabling systemd services..."
    systemctl daemon-reload
    systemctl enable fabmo.service
    systemctl enable fabmo-updater.service
    systemctl enable network-monitor.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path

    echo "Systemd services setup complete."
    echo ""
}

some_extras () {
    # Install a ShopBot starter on Desktop; may work, still needs run setting File Manager to not ask options on launch executable file.
    install_file "$RESOURCE_DIR/shopbot.desktop" "/home/pi/Desktop/shopbot.desktop"
    install_file "$RESOURCE_DIR/chrome-eoehjepgffkecmikenhncmboihmfijif-Default.desktop" "/home/pi/.local/share/applications/chrome-eoehjepgffkecmikenhncmboihmfijif-Default.desktop"
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
    #setup_expand_rootfs
    some_extras
    echo "BUILD, Installation, and Configuration Complete. ==============(remove BUILD files?)===="
    echo ""
    echo "MANUAL STEPS NOW REQUIRED:"
    echo "-Check to make sure expansion call is in cmdline.txt; last line should have init=/usr/lib/raspberrypi-sys-mods/firstboot"
    echo "-Enable running from desktop in FileManager Prefs."
    echo "-Set color for virtual keyboard in onboard."
    echo "-? Set up rotation for small screen."
    echo "-**STILL have not gotten Chrome config to save right; need to check that."
    echo ""
    echo ""
    echo ""
    echo ""
}

# Execute main installation function 
main_installation
