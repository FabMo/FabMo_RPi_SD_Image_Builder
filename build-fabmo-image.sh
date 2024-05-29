#!/bin/bash -e

# Variables
RESOURCE_DIR="/home/pi/Scripts/resources"

# Function to wait for the dpkg lock to be released
wait_for_dpkg_lock() {
    while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Waiting for dpkg lock to be released..."
        sleep 5
    done
}

# Clean any existing install
clean() {
    rm -rf /fabmo
    rm -rf /fabmo-updater
    rm -rf /opt/fabmo
}

# Function to copy files with logging
copy_files() {
    echo "Copying files from $1 to $2..."
    mkdir -p "$(dirname "$2")"
    cp -r $1 $2
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
    apt-get install -y bossa-cli hostapd dnsmasq vim onboard xserver-xorg-input-libinput pi-package jackd2
    # Preconfigure jackd2 (audio) to allow real-time process priority
    debconf-set-selections <<< "jackd2 jackd/tweak_rt_limits boolean true"
    echo "Packages installed."
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
    if ! grep -q "^disable_splash=1" /boot/firmware/config.txt; then
        echo "disable_splash=1" >> /boot/firmware/config.txt
    fi
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
    install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf"
    copy_files "$RESOURCE_DIR/NetworkManager/system-connections" "/etc/NetworkManager/system-connections"
    # Create or edit the systemd override for dnsmasq
    mkdir -p /etc/systemd/system/dnsmasq.service.d
    sudo tee /etc/systemd/system/dnsmasq.service.d/override.conf > /dev/null <<EOF
    [Unit]
    After=network-online.target
    Wants=network-online.target
EOF
    # Reload systemd and restart dnsmasq
    sudo systemctl daemon-reload
    sudo systemctl restart dnsmasq

    # Network Monitoring and Display Utilities
    mkdir -p /usr/local/bin
    install_file "$RESOURCE_DIR/urs-local-bin/network_monitor.sh" "/usr/local/bin/network_monitor.sh"
    sudo chmod +x /usr/local/bin/network_monitor.sh
    copy_files "$RESOURCE_DIR/export_network_config_thumb.sh" "/usr/local/bin"

    # User Utilities
    mkdir -p /home/pi/Scripts
    copy_files "$RESOURCE_DIR/fabmo.bashrc" "/home/pi/.bashrc"
    copy_files "$RESOURCE_DIR/dev-build.sh" "/home/pi/Scripts"
    copy_files "$RESOURCE_DIR/ck_services.sh" "/home/pi/Scripts"
    copy_files "$RESOURCE_DIR/temp_throttle_diag.sh" "/home/pi/Scripts"

    # Key USB symlink file for FabMo and VFD
    install_file "$RESOURCE_DIR/99-fabmo-usb.rules" "/etc/udev/rules.d/"

    # SystemD Service Files
    copy_files "$RESOURCE_DIR/sysd-services" "/etc/systemd/system"
    systemctl daemon-reload
    systemctl enable fabmo.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable fabmo-updater.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path

    # Boot and User Interface Resources
    install_file "$RESOURCE_DIR/FabMo-Icon-03-left.png" "/usr/share/plymouth/themes/pix/splash.png"
    install_file "$RESOURCE_DIR/shopbot-pi-bkgnd.png" "/home/pi/Pictures/shopbot-pi-bkgnd.png"
    install_file "$RESOURCE_DIR/FabMo-Icon-03.png" "/home/pi/Pictures/FabMo-Icon-03.png"
    install_file "$RESOURCE_DIR/icon.png" "/home/pi/Pictures/icon.png"
    plymouth-set-default-theme --rebuild-initrd pix
    install_file "$RESOURCE_DIR/fabmo_linux_version.txt" "/boot"
    install_file "$RESOURCE_DIR/fabmo-release.txt" "/etc"
}

# Set up directories and copy configuration files 
setup_desktop_environment() { 
    echo "Setting up desktop environment..."
    mkdir -p /home/pi/.config/pcmanfm/LXDE-pi 
    mkdir -p /home/pi/Desktop 
    mkdir -p /etc/X11/xorg.conf.d 
    # Copy configuration files  
    cp $RESOURCE_DIR/desktop-items-0.conf /etc/xdg/pcmanfm/LXDE-pi/ 
    cp $RESOURCE_DIR/panel /etc/xdg/lxpanel/LXDE-pi/panels/ 
    cp $RESOURCE_DIR/autostart /etc/xdg/lxsession/LXDE-pi/ 
    cp $RESOURCE_DIR/chrome-ibibgpobdkbalokofchnpkllnjgfddln-Default.desktop /home/pi/.local/share/applications/ 
    cp $RESOURCE_DIR/40-libinput.conf /etc/X11/xorg.conf.d/ 
    echo "Desktop environment set up."
}

# Setup FabMo
setup_fabmo() {
    echo "cloning fabmo-engine"
    git clone https://github.com/FabMo/FabMo-Engine.git /fabmo
    cd /fabmo
    npm install
    npm run build 

    echo "cloning fabmo-updater"
    git clone https://github.com/FabMo/FabMo-Updater.git /fabmo-updater
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

    if [ ! -f /usr/lib/systemd/system/dnsmasq.service ]; then
        ln -s /usr/lib/systemd/system/dnsmasq.service .
        echo "Created /usr/lib/systemd/system/dnsmasq.service"
    fi

    echo "Enabling systemd services..."
    systemctl enable fabmo.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable fabmo-updater.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path
    systemctl enable dnsmasq

    echo "Systemd services setup complete."
}

# Main installation
main_installation() {
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
