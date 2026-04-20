#!/bin/bash
# Diagnostic script to check boot display configuration

echo "=== FabMo Boot Display Configuration Check ==="
echo ""

echo "1. Checking /boot/firmware/config.txt settings:"
echo "   disable_fw_kms_setup:"
grep -E "^disable_fw_kms_setup=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo "   disable_overscan:"
grep -E "^disable_overscan=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo "   avoid_warnings:"
grep -E "^avoid_warnings=" /boot/firmware/config.txt || echo "   NOT SET (should be =1)"
echo ""

echo "2. Checking /boot/firmware/cmdline.txt:"
cat /boot/firmware/cmdline.txt
echo ""
echo "   Should contain: quiet loglevel=3 logo.nologo console=tty3 splash"
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
    systemctl status plymouth-wait.service --no-pager
else
    echo "   plymouth-wait.service NOT FOUND"
fi
echo ""

echo "8. Checking restore-boot-params service:"
if systemctl list-unit-files | grep -q restore-boot-params.service; then
    echo "   restore-boot-params.service: FOUND"
    systemctl is-enabled restore-boot-params.service
    if [ -f /var/lib/fabmo-boot-params-restored ]; then
        echo "   Boot params have been restored (marker file exists)"
    else
        echo "   Boot params not yet restored (marker file missing)"
    fi
else
    echo "   restore-boot-params.service NOT FOUND"
    echo "   WARNING: Boot parameters may be lost after firstboot!"
fi
echo ""

echo "9. Checking initramfs:"
ls -lh /boot/firmware/initramfs* | tail -3
echo ""

echo "=== End of diagnostics ==="
echo ""
echo "To test boot display:"
echo "  1. Check that all settings above are correct"
echo "  2. Reboot and observe the boot sequence"
echo "  3. You should NOT see: rainbow splash, scrolling text"
echo "  4. You SHOULD see: FabMo logo for ~3-5 seconds"
echo ""
echo "NOTE: If boot display stops working after the first boot,"
echo "      it means firstboot rewrote cmdline.txt."
echo "      The restore-boot-params.service should fix this automatically."
