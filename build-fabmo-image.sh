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

# # Function to copy files with logging
# copy_files() {
#     echo "Copying files from $1 to $2..."
#     mkdir -p "$(dirname "$2")"
#     cp -r $1 $2
#     echo "Files copied from $1 to $2"
# }

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
    apt-get install -y bossa-cli hostapd dnsmasq onboard xserver-xorg-input-libinput pi-package jackd2
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

    echo "System Configurations set."
    echo ""
}

# Copy all network, user utility, and system files
copy_all_files() {
    echo "Copying network, user utility, and system files..."
    # Network Configurations
    install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf"
    # NetworkManager system-connections
    copy_files "$RESOURCE_DIR/NetworkManager/system-connections" "/etc/NetworkManager/system-connections"
    # NetworkManager make sure we have the right permissions on these files, they are sensitive
    chmod 600 /etc/NetworkManager/system-connections/*
    # Key dnsmasq configuration files
    install_file "$RESOURCE_DIR/dnsmasq.conf" "/etc/dnsmasq.conf"
    # Make sure we have the right permissions on this file, it is sensitive
    chmod 755 /etc/dnsmasq.conf

    # Network Monitoring and IP Display Utilities for FabMo along with some usable diagnostic scripts
    mkdir -p /usr/local/bin
    copy_files "$RESOURCE_DIR/usr-local-bin" "/usr/local/bin"

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
    plymouth-set-default-theme --rebuild-initrd pix
    install_file "$RESOURCE_DIR/fabmo_linux_version.txt" "/boot"
    install_file "$RESOURCE_DIR/fabmo-release.txt" "/etc"

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
    cp $RESOURCE_DIR/autostart /etc/xdg/lxsession/LXDE-pi/ 
    cp $RESOURCE_DIR/chrome-ibibgpobdkbalokofchnpkllnjgfddln-Default.desktop /home/pi/.local/share/applications/ 
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
    echo "installed fabmo-updater"

    echo "FabMo and Updater done ..."
    echo ""
}

# SystemD
load_and_initialize_systemd_services() {
    echo "Setting up systemd services..."

    # FabMo and Updater SystemD Service symlinks to files
    cd /etc/systemd/system
    echo "Creating systemd sym-links from fabmo ..."
    SERVICES=("fabmo.service" "network-monitor.service" "camera-server-1.service" "camera-server-2.service" "export-netcfg-thumbdrive.service" "export-netcfg-thumbdrive.path")
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

    # Make sure files in /fabmo/files are executable
    chmod +x /fabmo/files/*
    # Make sure files in /fabmo-updater/files are executable
    chmod +x /fabmo-updater/files/*

    echo "Enabling systemd services..."
    systemctl daemon-reload
    systemctl enable fabmo.service
    systemctl enable fabmo-updater.service
    systemctl enable network-monitor.service
    systemctl enable camera-server-1.service
    systemctl enable camera-server-2.service
    systemctl enable export-netcfg-thumbdrive.service
    systemctl enable export-netcfg-thumbdrive.path
    systemctl enable dnsmasq

    echo "Systemd services setup complete."
    echo ""
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
    echo "BUILD, Installation, and Configuration Complete. ==============(remove BUILD files?)===="
    echo ""
}

# Execute main installation function 
main_installation
