#!/bin/bash
# Restore FabMo Network Configuration
# This script restores network configuration files that may have been accidentally deleted

set -e  # Exit on error

RESOURCE_DIR="/fabmo_image_builder/resources"
BACKUP_DIR="/tmp/fabmo-network-backup-$(date +%Y%m%d-%H%M%S)"

echo "================================================================================"
echo "FabMo Network Configuration Restoration Script"
echo "================================================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Verify resource directory exists
if [ ! -d "$RESOURCE_DIR" ]; then
    echo "ERROR: Resource directory not found: $RESOURCE_DIR"
    exit 1
fi

# Create backup directory
echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Function to backup and install a file
install_file() {
    local src="$1"
    local dest="$2"
    
    if [ ! -f "$src" ]; then
        echo "  WARNING: Source file not found: $src"
        return 1
    fi
    
    # Backup existing file if it exists
    if [ -f "$dest" ]; then
        echo "  Backing up existing: $dest"
        cp -p "$dest" "$BACKUP_DIR/"
    fi
    
    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"
    
    # Copy the file
    echo "  Installing: $dest"
    cp "$src" "$dest"
    
    return 0
}

# Function to backup and copy a directory
copy_directory() {
    local src="$1"
    local dest="$2"
    
    if [ ! -d "$src" ]; then
        echo "  WARNING: Source directory not found: $src"
        return 1
    fi
    
    # Backup existing directory if it exists
    if [ -d "$dest" ]; then
        echo "  Backing up existing directory: $dest"
        mkdir -p "$BACKUP_DIR/$(dirname "$dest")"
        cp -rp "$dest" "$BACKUP_DIR/$(dirname "$dest")/" 2>/dev/null || true
    fi
    
    # Create destination directory
    mkdir -p "$dest"
    
    # Copy all files
    echo "  Installing directory contents: $dest"
    cp -r "$src"/* "$dest/"
    
    return 0
}

echo ""
echo "Step 1: Restoring NetworkManager Configuration"
echo "--------------------------------------------------------------------------------"

# Main NetworkManager config
install_file "$RESOURCE_DIR/NetworkManager/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf"

# NetworkManager connection profiles (system-connections)
echo ""
echo "Installing NetworkManager connection profiles..."
copy_directory "$RESOURCE_DIR/NetworkManager/system-connections" "/etc/NetworkManager/system-connections"

# Set correct permissions on connection files (required by NetworkManager)
echo "Setting permissions on connection profiles (600 for security)..."
chmod 600 /etc/NetworkManager/system-connections/* 2>/dev/null || true

# Make connection files immutable to prevent accidental deletion
echo "Setting immutable flags on connection profiles to prevent accidental deletion..."
chattr +i /etc/NetworkManager/system-connections/lan-connection 2>/dev/null || true
chattr +i /etc/NetworkManager/system-connections/direct-connection 2>/dev/null || true
chattr +i /etc/NetworkManager/system-connections/wlan0_ap.nmconnection 2>/dev/null || true
echo "  ✓ Connection profiles protected (use 'chattr -i' to modify)"

# NetworkManager dispatcher scripts
echo ""
echo "Installing NetworkManager dispatcher scripts..."
copy_directory "$RESOURCE_DIR/NetworkManager/dispatcher.d" "/etc/NetworkManager/dispatcher.d"
chmod 755 /etc/NetworkManager/dispatcher.d/* 2>/dev/null || true

echo ""
echo "Step 2: Restoring dnsmasq Configuration"
echo "--------------------------------------------------------------------------------"

# Main dnsmasq config
install_file "$RESOURCE_DIR/dnsmasq/dnsmasq.conf" "/etc/dnsmasq.conf"
chmod 644 /etc/dnsmasq.conf 2>/dev/null || true

# Create dnsmasq.d directory
mkdir -p /etc/dnsmasq.d
chmod 755 /etc/dnsmasq.d

# Mode-specific dnsmasq configurations
install_file "$RESOURCE_DIR/dnsmasq/ap-only.conf" "/etc/dnsmasq.d/ap-only.conf"
install_file "$RESOURCE_DIR/dnsmasq/direct-mode.conf" "/etc/dnsmasq.d/direct-mode.conf"
chmod 644 /etc/dnsmasq.d/ap-only.conf 2>/dev/null || true
chmod 644 /etc/dnsmasq.d/direct-mode.conf 2>/dev/null || true

# Create active-mode symlink (default to ap-only for safety)
echo ""
echo "Creating active-mode.conf symlink (defaulting to ap-only mode)..."
if [ -L /etc/dnsmasq.d/active-mode.conf ]; then
    rm /etc/dnsmasq.d/active-mode.conf
fi
ln -sf /etc/dnsmasq.d/ap-only.conf /etc/dnsmasq.d/active-mode.conf
echo "  Created: /etc/dnsmasq.d/active-mode.conf -> ap-only.conf"

echo ""
echo "Step 3: Verifying Services"
echo "--------------------------------------------------------------------------------"

# Reload NetworkManager to pick up new configurations
echo "Reloading NetworkManager..."
systemctl reload NetworkManager || systemctl restart NetworkManager

# Check if dnsmasq is enabled
if systemctl is-enabled dnsmasq >/dev/null 2>&1; then
    echo "Restarting dnsmasq..."
    systemctl restart dnsmasq
else
    echo "Enabling and starting dnsmasq..."
    systemctl enable dnsmasq
    systemctl start dnsmasq
fi

# Check if hostapd should be disabled (NetworkManager manages AP)
if systemctl is-enabled hostapd >/dev/null 2>&1; then
    echo ""
    echo "NOTE: Disabling standalone hostapd (NetworkManager manages AP via wlan0_ap)..."
    systemctl disable hostapd
    systemctl stop hostapd 2>/dev/null || true
fi

echo ""
echo "================================================================================"
echo "Network Configuration Restoration Complete!"
echo "================================================================================"
echo ""
echo "Backup of original files saved to: $BACKUP_DIR"
echo ""
echo "Restored configurations:"
echo "  ✓ NetworkManager connection profiles:"
echo "      - lan-connection (DHCP on LAN)"
echo "      - direct-connection (192.168.44.1 static)"
echo "      - wlan0_ap (Access Point at 192.168.42.1)"
echo "  ✓ Connection profiles protected with immutable flag"
echo "  ✓ NetworkManager dispatcher (AP channel sync)"
echo "  ✓ dnsmasq configurations (ap-only, direct-mode)"
echo "  ✓ Active mode: ap-only (safe for LAN connections)"
echo ""
echo "Network profiles available:"
echo "  • LAN Mode: eth0 uses DHCP, AP serves 192.168.42.x"
echo "  • Direct Mode: eth0 static 192.168.44.1, AP serves 192.168.42.x"
echo "  • WiFi Client: Connect to WiFi networks, AP remains available"
echo ""
echo "To verify network status, run:"
echo "  ck_services"
echo ""
echo "To check which connection profiles are available:"
echo "  nmcli connection show"
echo ""
echo "To manually activate a profile:"
echo "  sudo nmcli connection up lan-connection"
echo "  sudo nmcli connection up direct-connection"
echo "  sudo nmcli connection up wlan0_ap"
echo ""
echo "IMPORTANT: Connection profiles are now protected with immutable flags."
echo "           This prevents accidental deletion via NetworkManager UI."
echo "           To modify a protected connection:"
echo "             sudo chattr -i /etc/NetworkManager/system-connections/[connection-name]"
echo "             # make your changes"
echo "             sudo chattr +i /etc/NetworkManager/system-connections/[connection-name]"
echo ""
echo "NOTE: If you were connected via WiFi, you may need to reconnect."
echo "      The system should automatically bring up ethernet connections."
echo ""
echo "Reboot recommended to ensure all changes take effect:"
echo "  sudo reboot"
echo ""
echo "================================================================================"
