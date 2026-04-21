#!/bin/bash
# Manual fix script for RPi 5 boot display issues
# Run this on your current build to implement the robust boot display fix

set -e

echo "=== FabMo RPi 5 Boot Display Fix Script ==="
echo ""
echo "This will:"
echo "  1. Create boot parameter enforcement script"
echo "  2. Set up systemd service to maintain boot params"
echo "  3. Configure Plymouth properly"
echo "  4. Mask getty to prevent console breakthrough"
echo "  5. Rebuild initramfs"
echo ""
read -p "Press Enter to continue..."

# 1. Create boot parameter enforcement script
echo "Creating boot parameter enforcement script..."
sudo tee /usr/local/bin/ensure-fabmo-boot-params.sh > /dev/null <<'EOF'
#!/bin/bash
# Ensure FabMo boot display parameters are always present

CMDLINE_FILE="/boot/firmware/cmdline.txt"
REQUIRED_PARAMS="quiet loglevel=3 logo.nologo vt.global_cursor_default=0 console=tty3 consoleblank=1 splash plymouth.ignore-serial-consoles"

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
    sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g; s/ consoleblank=[0-9]//g' "$CMDLINE_FILE"
    # Add them back
    sed -i "1 s/$/ $REQUIRED_PARAMS/" "$CMDLINE_FILE"
    echo "Boot parameters restored."
    # Ensure initramfs is current
    update-initramfs -u -k all
fi
EOF

sudo chmod +x /usr/local/bin/ensure-fabmo-boot-params.sh

# 2. Run the script NOW to fix current boot params
echo "Running boot parameter fix now..."
sudo /usr/local/bin/ensure-fabmo-boot-params.sh

# 2b. Fix config.txt for cold boot (power-on) issues
echo "Configuring config.txt for cold boot..."
# Add or ensure these settings exist in config.txt
grep -q "^disable_fw_kms_setup=1" /boot/firmware/config.txt || echo "disable_fw_kms_setup=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^disable_splash=1" /boot/firmware/config.txt || echo "disable_splash=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^boot_delay=0" /boot/firmware/config.txt || echo "boot_delay=0" | sudo tee -a /boot/firmware/config.txt
grep -q "^disable_overscan=1" /boot/firmware/config.txt || echo "disable_overscan=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^avoid_warnings=1" /boot/firmware/config.txt || echo "avoid_warnings=1" | sudo tee -a /boot/firmware/config.txt

# 3. Create systemd service for boot param enforcement
echo "Creating fabmo-boot-params.service..."
sudo tee /etc/systemd/system/fabmo-boot-params.service > /dev/null <<EOF
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

sudo systemctl daemon-reload
sudo systemctl enable fabmo-boot-params.service

# 4. Configure getty to prevent console breakthrough
echo "Masking getty@tty1 to prevent console breakthrough..."
sudo systemctl mask getty@tty1.service

# Create drop-in for delay
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/noclear.conf > /dev/null <<EOF
[Service]
ExecStartPre=/bin/sleep 5
EOF

# 5. Ensure Plymouth is properly configured
echo "Verifying Plymouth configuration..."
if [ ! -f /etc/plymouth/plymouthd.conf ]; then
    sudo mkdir -p /etc/plymouth
    sudo tee /etc/plymouth/plymouthd.conf > /dev/null <<EOF
[Daemon]
Theme=pix
ShowDelay=0
DeviceTimeout=30
EOF
fi

# 6. Ensure Plymouth theme is set
echo "Setting Plymouth theme..."
sudo plymouth-set-default-theme pix

# 7. Check if plymouth-wait.service exists, if not create it
if ! systemctl list-unit-files | grep -q plymouth-wait.service; then
    echo "Creating plymouth-wait.service..."
    sudo tee /etc/systemd/system/plymouth-wait.service > /dev/null <<EOF
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
    sudo systemctl daemon-reload
    sudo systemctl enable plymouth-wait.service
fi

# 8. Rebuild initramfs with ALL kernels
echo "Rebuilding initramfs (this may take a minute)..."
sudo update-initramfs -u -k all

# 9. Show final configuration
echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Current /boot/firmware/cmdline.txt:"
cat /boot/firmware/cmdline.txt
echo ""
echo "Services enabled:"
systemctl is-enabled fabmo-boot-params.service
systemctl is-enabled plymouth-wait.service
echo ""
echo "getty@tty1 masked:"
systemctl is-masked getty@tty1.service
echo ""
echo "=== Ready to Reboot ==="
echo ""
echo "The boot display should now work consistently."
echo "Reboot now to test: sudo reboot"
