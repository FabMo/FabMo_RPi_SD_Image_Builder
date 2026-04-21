#!/bin/bash
# Fix both cold boot display and auto-login issues
# Run this to fix your current build

set -e

echo "=== FabMo Cold Boot Display + Auto-Login Fix ==="
echo ""
echo "This will fix:"
echo "  1. White/red console screen on cold boot (power-on)"
echo "  2. Login prompt appearing (restore auto-login)"
echo ""
read -p "Press Enter to continue..."

# 1. Fix auto-login (restore it)
echo "Restoring auto-login for user pi..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/22-autologin.conf > /dev/null <<EOF
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
EOF

# 2. Unmask getty@tty1 (it was breaking auto-login)
echo "Unmasking getty@tty1..."
sudo systemctl unmask getty@tty1.service

# 3. Configure getty to not interfere with Plymouth
echo "Configuring getty to delay after Plymouth..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Unit]
After=plymouth-quit-wait.service

[Service]
TTYVTDisallocate=no
EOF

# 4. Update config.txt for aggressive cold boot suppression
echo "Updating config.txt for cold boot..."
# Ensure all settings exist (some may already be there)
grep -q "^disable_fw_kms_setup=1" /boot/firmware/config.txt || echo "disable_fw_kms_setup=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^disable_splash=1" /boot/firmware/config.txt || echo "disable_splash=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^boot_delay=0" /boot/firmware/config.txt || echo "boot_delay=0" | sudo tee -a /boot/firmware/config.txt
grep -q "^disable_overscan=1" /boot/firmware/config.txt || echo "disable_overscan=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^avoid_warnings=1" /boot/firmware/config.txt || echo "avoid_warnings=1" | sudo tee -a /boot/firmware/config.txt
grep -q "^uart_2ndstage=0" /boot/firmware/config.txt || echo "uart_2ndstage=0" | sudo tee -a /boot/firmware/config.txt
grep -q "^enable_uart=0" /boot/firmware/config.txt || echo "enable_uart=0" | sudo tee -a /boot/firmware/config.txt

echo "Disabling any UART console in cmdline.txt..."
# Remove any console=serial or console=ttyAMA references
sudo sed -i 's/ console=serial[^ ]*//g; s/ console=ttyAMA[^ ]*//g' /boot/firmware/cmdline.txt

# 5. Update boot parameters for maximum console suppression
echo "Updating cmdline.txt for aggressive console suppression..."
REQUIRED_PARAMS="quiet loglevel=0 rd.systemd.show_status=false rd.udev.log_level=0 logo.nologo vt.global_cursor_default=0 console=tty3 consoleblank=0 splash plymouth.ignore-serial-consoles"

# Clean up old parameters first
sudo sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g; s/ consoleblank=[0-9]//g; s/ rd\.systemd\.show_status=[^ ]*//g; s/ rd\.udev\.log_level=[^ ]*//g' /boot/firmware/cmdline.txt

# Add new parameters
sudo sed -i "1 s/$/ $REQUIRED_PARAMS/" /boot/firmware/cmdline.txt

# 6. Update the boot parameter enforcement script
echo "Updating boot parameter enforcement script..."
sudo tee /usr/local/bin/ensure-fabmo-boot-params.sh > /dev/null <<'EOF'
#!/bin/bash
CMDLINE_FILE="/boot/firmware/cmdline.txt"
REQUIRED_PARAMS="quiet loglevel=0 rd.systemd.show_status=false rd.udev.log_level=0 logo.nologo vt.global_cursor_default=0 console=tty3 consoleblank=0 splash plymouth.ignore-serial-consoles"
CURRENT=$(cat "$CMDLINE_FILE")
NEEDS_UPDATE=0
for PARAM in $REQUIRED_PARAMS; do
    if [[ ! "$CURRENT" =~ $PARAM ]]; then
        NEEDS_UPDATE=1
        break
    fi
done
if [ $NEEDS_UPDATE -eq 1 ]; then
    sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g; s/ consoleblank=[0-9]//g; s/ rd\.systemd\.show_status=[^ ]*//g; s/ rd\.udev\.log_level=[^ ]*//g' "$CMDLINE_FILE"
    sed -i "1 s/$/ $REQUIRED_PARAMS/" "$CMDLINE_FILE"
    update-initramfs -u -k all
fi
EOF
sudo chmod +x /usr/local/bin/ensure-fabmo-boot-params.sh

# 6b. Ensure Plymouth is in initramfs and starts early
echo "Configuring Plymouth for initramfs..."
# Force framebuffer for Plymouth
if [ -f /etc/initramfs-tools/conf.d/splash ]; then
    sudo sed -i 's/^FRAMEBUFFER=.*/FRAMEBUFFER=y/' /etc/initramfs-tools/conf.d/splash
else
    echo "FRAMEBUFFER=y" | sudo tee /etc/initramfs-tools/conf.d/splash
fi

# Ensure Plymouth theme is set
sudo plymouth-set-default-theme pix

# 7. Rebuild initramfs
echo "Rebuilding initramfs..."
sudo update-initramfs -u -k all

# 8. Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# 9. Show results
echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Auto-login configured:"
cat /etc/lightdm/lightdm.conf.d/22-autologin.conf
echo ""
echo "Boot parameters:"
cat /boot/firmware/cmdline.txt
echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Power off COMPLETELY: sudo poweroff"
echo "2. Wait 10 seconds"
echo "3. Power back on (cold boot test)"
echo ""
echo "Expected result:"
echo "  - NO white/red console screen"
echo "  - FabMo logo for 3-5 seconds"
echo "  - Desktop appears WITHOUT login prompt"
echo ""
