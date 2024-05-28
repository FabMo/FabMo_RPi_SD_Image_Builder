#!/bin/bash -e

# (run as root)
# Variables
RESOURCE_DIR="/home/pi/Scripts/resources"
TARGET_DIR=""

# Clean any existing install
clean () {
    rm -rf /fabmo
    rm -rf /fabmo-updater
    rm -rf /opt/fabmo
}

# Function to copy files with logging
copy_files() {
    echo "Copying files from $1 to $2..."
    cp -r $1 $2
    echo "Files copied from $1 to $2"
}

# Function to handle simple file operations
install_file() {
    echo "Installing $1 to $2..."
    cp $1 $2
    echo "Installed $1 to $2"
}

# Install required packages and configure system
install_packages_and_configure() {
    echo "Updating package lists..."
    apt-get update
    apt-get install -y bossa-cli hostapd dnsmasq vim onboard xserver-xorg-input-libinput pi-package jackd2
    # Preconfigure jackd2 (audio) to allow real-time process priority (maybe relevant to feedback sounds?)
    debconf-set-selections <<< "jackd2 jackd/tweak_rt_limits boolean true"
    echo "Packages installed."
}

# Setup System Configuration (country also done is basic first start of OS download)
setup_system() {
    echo "Setting up system configurations..."
    #do the basic configs that suit FabMo
    #no screen blanking, etc
    raspi-config nonint do_blanking 1
    raspi-config nonint do_wifi_country US
    raspi-config nonint do_rgpio 0
    raspi-config nonint do_i2c 0
    raspi-config nonint do_ssh 0
    raspi-config nonint do_hostname shopbot
    #raspi-config nonint do_expand_rootfs

    #get node.js set up with appropriate standards and encryption
    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    #curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    # over-ride on repeated runs ...
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes --batch -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
    apt-get update
    apt-get install nodejs -y

    echo "Installing npm..."
    apt-get install -y npm
    echo "npm installed."

    # Bookworm version ... dealing with initialization screens
    # Add disable_splash=1 to /boot/config.txt if not already present
    if ! grep -q "^disable_splash=1" /boot/firmware/config.txt; then
        echo "disable_splash=1" >> /boot/firmware/config.txt
    fi
    # Add quiet and splash to /boot/cmdline.txt if not already present
    if ! grep -q "quiet" /boot/firmware/cmdline.txt; then
        sed -i '1 s/$/ quiet/' /boot/firmware/cmdline.txt
    fi
    if ! grep -q "splash" /boot/firmware/cmdline.txt; then
        sed -i '1 s/$/ splash/' /boot/firmware/cmdline.txt
    fi

    echo "System Configurations set."
}

# Copy all network, user utility, and system files
copy_all_files() {
    # Network Configurations
    install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "$TARGET_DIR/etc//NetworkManager/NetworkManager.conf"
    copy_files "$RESOURCE_DIR/NetworkManager/system-connections" "$TARGET_DIR/etc//NetworkManager/system-connections"
    # Create or edit the systemd override for dnsmasq
#    sudo tee /etc/systemd/system/dnsmasq.service.d/override.conf > /dev/null <<EOF
    [Unit]
    After=network-online.target
    Wants=network-online.target
    EOF
    # Reload systemd and restart dnsmasq
    sudo systemctl daemon-reload
    sudo systemctl restart dnsmasq
 
#    copy_files "$RESOURCE_DIR/hostapd" "$TARGET_DIR/etc/hostapd"
#    install_file "$RESOURCE_DIR/hostapd/hostapd" "$TARGET_DIR/etc/default/hostapd"
#    copy_files "$RESOURCE_DIR/dhcp" "$TARGET_DIR/etc/dhcp"

    # Network Monitoring and Display Utilities
    mkdir -p $TARGET_DIR/usr/local/bin
    install_file "$RESOURCE_DIR/network_monitor.sh" "$TARGET_DIR/usr/local/bin/network_monitor.sh"
    # Make sure we can execute the network monitor script
    sudo chmod +x /usr/local/bin/network_monitor.sh
#    copy_files "$RESOURCE_DIR/ip_address_display.py" "$TARGET_DIR/home/pi/bin"
#    copy_files "$RESOURCE_DIR/ip_address_display.sh" "$TARGET_DIR/home/pi/bin"
#    copy_files "$RESOURCE_DIR/change_ssid.sh" "$TARGET_DIR/home/pi/bin"
#    copy_files "$RESOURCE_DIR/ck_eth0.sh" "$TARGET_DIR/home/pi/bin"
    copy_files "$RESOURCE_DIR/export_network_config_thumb.sh" "$TARGET_DIR/usr/local/bin"

    # User Utilities
    mkdir -p $TARGET_DIR/home/pi/Scripts
    copy_files "$RESOURCE_DIR/fabmo.bashrc" "$TARGET_DIR/home/pi/.bashrc"
    copy_files "$RESOURCE_DIR/dev-build.sh" "$TARGET_DIR/home/pi/Scripts"
    copy_files "$RESOURCE_DIR/ck_services.sh" "$TARGET_DIR/home/pi/Scripts"
    copy_files "$RESOURCE_DIR/temp_throttle_diag.sh" "$TARGET_DIR/home/pi/Scripts"

    # Key USB symlink file for FabMo and VFD
    install_file "$RESOURCE_DIR/99-fabmo-usb.rules" "$TARGET_DIR/etc/udev/rules.d/"
    
    # SystemD Service Files
    copy_files "$RESOURCE_DIR/sysd-services" "$TARGET_DIR/etc/systemd/system"
    systemctl daemon-reload
    systemctl enable fabmo.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable fabmo-updater.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path

#    copy_files "$RESOURCE_DIR/maintain_network_mode.service" "$TARGET_DIR/etc/systemd/system"

    # Boot and User Interface Resources
    install_file "$RESOURCE_DIR/FabMo-Icon-03-left.png" "$TARGET_DIR/usr/share/plymouth/themes/pix/splash.png"
    install_file "$RESOURCE_DIR/shopbot-pi-bkgnd.png" "$TARGET_DIR/home/pi/Pictures/shopbot-pi-bkgnd.png"
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "$TARGET_DIR/home/pi/Pictures/FabMo-Icon-03.png"
    install_file "$RESOURCE_DIR/icon.png" "$TARGET_DIR/home/pi/Pictures/icon.png"
    # Reset to call default splash from pix
    #plymouth-set-default-theme pix
    #sudo update-initramfs -u -v
    plymouth-set-default-theme --rebuild-initrd pix
    # Store Version INFO
    install_file "$RESOURCE_DIR/fabmo_linux_version.txt" "$TARGET_DIR/boot"
    install_file "$RESOURCE_DIR/fabmo-release.txt" "$TARGET_DIR/etc"
}

# Set up directories and copy configuration files 
setup_desktop_environment() { 
    echo "Setting up desktop environment..."
    mkdir -p $TARGET_DIR/home/pi/.config/pcmanfm/LXDE-pi 
    mkdir -p $TARGET_DIR/home/pi/Desktop 
    mkdir -p $TARGET_DIR/etc/X11/xorg.conf.d 
# Copy configuration files  
    cp $RESOURCE_DIR/desktop-items-0.conf $TARGET_DIR/etc/xdg/pcmanfm/LXDE-pi/ 
    cp $RESOURCE_DIR/panel $TARGET_DIR/etc/xdg/lxpanel/LXDE-pi/panels/ 
    cp $RESOURCE_DIR/autostart $TARGET_DIR/etc/xdg/lxsession/LXDE-pi/ 
    cp $RESOURCE_DIR/chrome-ibibgpobdkbalokofchnpkllnjgfddln-Default.desktop $TARGET_DIR/home/pi/.local/share/applications/ 
    cp $RESOURCE_DIR/40-libinput.conf $TARGET_DIR/etc/X11/xorg.conf.d/ 
    echo "Desktop environment set up."
}

#setup FabMo
setup_fabmo() {
    echo "cloning fabmo-engine"
    git clone https://github.com/FabMo/FabMo-Engine.git /fabmo
    cd /fabmo
    #git checkout {could change branches here}
    npm install
    npm run build 

    echo "cloning fabmo-updater"
    git clone https://github.com/FabMo/FabMo-Updater.git /fabmo-updater
    echo "installing fabmo-updater"
    cd /fabmo-updater
    npm install
    echo "installed fabmo-updater"
}


# SystemD
load_and_initialize_systemd_services() {
    echo "Setting up systemd services..."
    cd /etc/systemd/system

    SERVICES=("export-netcfg-thumbdrive.path" "export-netcfg-thumbdrive.service" "fabmo.service" "camera-server-1.service" "camera-server-2.service")
    for SERVICE in "${SERVICES[@]}"; do
        if [ ! -f "/fabmo/files/$SERVICE" ]; then
            ln -s "/fabmo/files/$SERVICE" .
            echo "Created /fabmo/files/$SERVICE"
        fi
    done

#    if [ ! -f /usr/lib/systemd/system/hostapd.service ]; then
#        ln -s /usr/lib/systemd/system/hostapd.service .
#        echo "Created /usr/lib/systemd/system/hostapd.service"
#    fi

    if [ ! -f /usr/lib/systemd/system/dnsmasq.service ]; then
        ln -s /usr/lib/systemd/system/dnsmasq.service .
        echo "Created /usr/lib/systemd/system/dnsmasq.service"
    fi

#    /etc/network_conf_fabmo/assigns_ip_addresses/chooseMe.sh

    echo "Enabling systemd services..."
    systemctl enable fabmo.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable fabmo-updater.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path
#    systemctl enable maintain_network_mode.service
    systemctl enable dnsmasq

    echo "Systemd services setup complete."
}


# Main installation
function main_installation() {
    clean
    install_packages_and_configure
    setup_system
    copy_all_files
    setup_desktop_environment
    setup_fabmo
    load_and_initialize_systemd_services
    echo "Installation and configuration complete."
 }

# Execute main installation function 
main_installation

