#!/bin/bash
# Cleanup script to revert overly aggressive settings that are no longer needed
# Run this on your current build to clean up unnecessary changes

set -e

echo "=== Cleanup Overly Aggressive Boot Settings ==="
echo ""
echo "This will:"
echo "  1. Remove UART disable settings (not needed, blocks serial debugging)"
echo "  2. Change loglevel from 0 to 3 (better error visibility)"
echo "  3. Remove excessive systemd/udev suppression"
echo "  4. Update boot parameter enforcement script"
echo ""
read -p "Press Enter to continue..."

# 1. Remove UART disable from config.txt (if present)
echo "Removing UART disable settings from config.txt..."
if grep -q "^uart_2ndstage=0" /boot/firmware/config.txt; then
    sudo sed -i '/^uart_2ndstage=0/d' /boot/firmware/config.txt
    echo "Removed: uart_2ndstage=0"
fi
if grep -q "^enable_uart=0" /boot/firmware/config.txt; then
    sudo sed -i '/^enable_uart=0/d' /boot/firmware/config.txt
    echo "Removed: enable_uart=0"
fi

# 2. Update cmdline.txt to less aggressive settings
echo ""
echo "Updating cmdline.txt to reasonable boot parameters..."
REQUIRED_PARAMS="quiet loglevel=3 logo.nologo vt.global_cursor_default=0 console=tty3 splash plymouth.ignore-serial-consoles"

# Remove all old parameters first
sudo sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g; s/ consoleblank=[0-9]//g; s/ rd\.systemd\.show_status=[^ ]*//g; s/ rd\.udev\.log_level=[^ ]*//g' /boot/firmware/cmdline.txt

# Add cleaner parameters
sudo sed -i "1 s/$/ $REQUIRED_PARAMS/" /boot/firmware/cmdline.txt

# 3. Update enforcement script to match
echo ""
echo "Updating boot parameter enforcement script..."
sudo tee /usr/local/bin/ensure-fabmo-boot-params.sh > /dev/null <<'EOF'
#!/bin/bash
CMDLINE_FILE="/boot/firmware/cmdline.txt"
REQUIRED_PARAMS="quiet loglevel=3 logo.nologo vt.global_cursor_default=0 console=tty3 splash plymouth.ignore-serial-consoles"
CURRENT=$(cat "$CMDLINE_FILE")
NEEDS_UPDATE=0
for PARAM in $REQUIRED_PARAMS; do
    if [[ ! "$CURRENT" =~ $PARAM ]]; then
        NEEDS_UPDATE=1
        break
    fi
done
if [ $NEEDS_UPDATE -eq 1 ]; then
    sed -i 's/ quiet//g; s/ splash//g; s/ loglevel=[0-9]//g; s/ logo\.nologo//g; s/ vt\.global_cursor_default=[0-9]//g; s/ console=tty[0-9]//g; s/ plymouth\.ignore-serial-consoles//g' "$CMDLINE_FILE"
    sed -i "1 s/$/ $REQUIRED_PARAMS/" "$CMDLINE_FILE"
    update-initramfs -u -k all
fi
EOF
sudo chmod +x /usr/local/bin/ensure-fabmo-boot-params.sh

# 4. Rebuild initramfs
echo ""
echo "Rebuilding initramfs..."
sudo update-initramfs -u -k all

# 5. Show results
echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Current config.txt settings:"
grep -E "^(disable_fw_kms_setup|disable_splash|boot_delay|disable_overscan|avoid_warnings)" /boot/firmware/config.txt
echo ""
echo "Should NOT see: uart_2ndstage or enable_uart"
echo ""
echo "Current cmdline.txt:"
cat /boot/firmware/cmdline.txt
echo ""
echo "Should have: loglevel=3 (not 0)"
echo "Should NOT have: rd.systemd.show_status, rd.udev.log_level, consoleblank"
echo ""
echo "=== All Done ==="
echo "Boot display should still work perfectly with these cleaner settings."
echo "Reboot to verify: sudo reboot"
echo ""
