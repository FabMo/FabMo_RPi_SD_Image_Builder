#!/bin/bash
# Diagnostic script to check boot display configuration

echo "=== FabMo Boot Display Configuration Check ==="
echo ""

echo "0. CRITICAL: Checking EEPROM network install setting (RPi 5):"
echo "   This is the actual fix for white/red screen on cold boot!"
vcgencmd bootloader_config | grep -i NET_INSTALL || echo "   Setting not found in bootloader config"
echo ""
echo "   Should show: NET_INSTALL_AT_POWER_ON=0 (disabled)"
echo "   If =1 (or missing on newer boards), run:"
echo "   sudo raspi-config → Advanced Options → Network Install UI → Disable"
echo ""

echo "1. Checking /boot/firmware/config.txt settings:"
echo "   disable_fw_kms_setup (for RPi 5):"
grep -E "^disable_fw_kms_setup=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo "   disable_splash (firmware splash):"
grep -E "^disable_splash=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo "   boot_delay (cold boot speed):"
grep -E "^boot_delay=" /boot/firmware/config.txt || echo "   NOT SET (should be =0)"
echo "   disable_overscan:"
grep -E "^disable_overscan=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo "   avoid_warnings:"
grep -E "^avoid_warnings=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo ""
echo "   SHOULD NOT SEE (reverted as unnecessary):"
grep -E "^(uart_2ndstage|enable_uart)=" /boot/firmware/config.txt && echo "   WARNING: UART settings found (should be removed)" || echo "   Good: No UART disable settings"
echo ""

echo "2. Checking /boot/firmware/cmdline.txt:"
cat /boot/firmware/cmdline.txt
echo ""
echo "   Should contain: quiet loglevel=3 logo.nologo console=tty3 splash"
echo "   Should NOT contain: loglevel=0, rd.systemd.show_status, rd.udev.log_level"
echo ""

echo "3. Checking Plymouth installation:"
which plymouth && echo "   Plymouth installed: YES" || echo "   Plymouth installed: NO"
plymouth --version
echo ""

echo "4. Checking Plymouth theme:"
plymouth-set-default-theme
echo "   (Should be: pix)"
echo ""

echo "5. Checking Plymouth configuration:"
if [ -f /etc/plymouth/plymouthd.conf ]; then
    cat /etc/plymouth/plymouthd.conf
else
    echo "   /etc/plymouth/plymouthd.conf NOT FOUND"
fi
echo ""

echo "6. Checking Plymouth splash image:"
if [ -f /usr/share/plymouth/themes/pix/splash.png ]; then
    ls -lh /usr/share/plymouth/themes/pix/splash.png
    echo "   Checking if it's FabMo logo:"
    md5sum /usr/share/plymouth/themes/pix/splash.png
    if [ -f /home/pi/Pictures/FabMo-Icon-03.png ]; then
        echo "   FabMo logo reference:"
        md5sum /home/pi/Pictures/FabMo-Icon-03.png
    fi
else
    echo "   splash.png NOT FOUND"
fi
echo ""

echo "7. Checking plymouth-wait service:"
if systemctl list-unit-files | grep -q plymouth-wait.service; then
    echo "   Status:"
    systemctl is-enabled plymouth-wait.service
    systemctl is-active plymouth-wait.service 2>/dev/null || echo "   (not currently active - normal when not booting)"
else
    echo "   plymouth-wait.service NOT FOUND"
fi
echo ""

echo "8. Checking fabmo-boot-params service:"
if systemctl list-unit-files | grep -q fabmo-boot-params.service; then
    echo "   Status:"
    systemctl is-enabled fabmo-boot-params.service
    if [ -f /usr/local/bin/ensure-fabmo-boot-params.sh ]; then
        echo "   Script exists: YES"
    else
        echo "   Script exists: NO - PROBLEM!"
    fi
else
    echo "   fabmo-boot-params.service NOT FOUND"
    echo "   WARNING: Boot parameters may be lost!"
fi
echo ""

echo "9. Checking getty@tty1 (should NOT be masked to allow auto-login):"
systemctl is-masked getty@tty1.service && echo "   Masked: YES (BAD - breaks auto-login)" || echo "   Masked: NO (good)"
if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
    echo "   Override configured: YES"
else
    echo "   Override configured: NO"
fi
echo ""

echo "10. Checking auto-login configuration:"
if [ -f /etc/lightdm/lightdm.conf.d/22-autologin.conf ]; then
    echo "   Auto-login file exists: YES"
    grep "autologin-user" /etc/lightdm/lightdm.conf.d/22-autologin.conf
else
    echo "   Auto-login file exists: NO (login prompt will appear)"
fi
echo ""

echo "11. Checking Plymouth service status:"
systemctl is-enabled plymouth-start.service 2>/dev/null && echo "   plymouth-start: enabled" || echo "   plymouth-start: NOT enabled"
systemctl is-enabled plymouth-quit.service 2>/dev/null && echo "   plymouth-quit: enabled" || echo "   plymouth-quit: NOT enabled"
echo ""

echo "12. Checking initramfs:"
ls -lh /boot/firmware/initramfs* 2>/dev/null | tail -3 || echo "   No initramfs files found"
echo ""

echo "=== End of diagnostics ==="
echo ""
echo "To test boot display:"
echo "  1. Check that all settings above are correct"
echo "  2. Run: sudo /usr/local/bin/ensure-fabmo-boot-params.sh"
echo "  3. Reboot and observe the boot sequence"
echo "  4. You should NOT see: rainbow splash, white/red screen, scrolling text"
echo "  5. You SHOULD see: FabMo logo for ~3-5 seconds"
echo ""
echo "If you see white/red screen with text, this means:"
echo "  - Plymouth is not starting (check step 10 above)"
echo "  - Console is breaking through (check step 9 above)"
echo "  - Boot parameters were stripped (check step 2 above)"
echo ""
echo "To manually fix after boot:"
echo "  sudo /usr/local/bin/ensure-fabmo-boot-params.sh"
echo "  sudo update-initramfs -u -k all"
echo "  sudo reboot"
