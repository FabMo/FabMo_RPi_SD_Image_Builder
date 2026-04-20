#!/bin/bash
# Cleanup script to remove build artifacts after SD card image is built
# Run this after build-fabmo-image.sh completes successfully

echo "Cleaning up build artifacts..."

# Remove the build script and resources from /home/pi/Scripts
if [ -d "/home/pi/Scripts/resources" ]; then
    echo "Removing /home/pi/Scripts/resources..."
    rm -rf /home/pi/Scripts/resources
fi

if [ -f "/home/pi/Scripts/build-fabmo-image.sh" ]; then
    echo "Removing /home/pi/Scripts/build-fabmo-image.sh..."
    rm -f /home/pi/Scripts/build-fabmo-image.sh
fi

# Remove the temporary Image_Builder repo
if [ -d "/Image_Builder" ]; then
    echo "Removing /Image_Builder repository..."
    rm -rf /Image_Builder
fi

# Remove this cleanup script itself
if [ -f "/home/pi/Scripts/cleanup-build.sh" ]; then
    echo "Removing cleanup script..."
    rm -f /home/pi/Scripts/cleanup-build.sh
fi

echo ""
echo "Cleanup complete!"
echo ""
echo "NEXT STEPS:"
echo "1. Adjust UI settings:"
echo "   - Set Task Bar: bottom, medium size"
echo "   - Set Desktop text color to #353A92 (dark blue)"
echo "   - Add RPI-CONNECT to Menu Bar (left side)"
echo "2. Verify /boot/fabmo-release.txt shows correct version"
echo "3. DO NOT REBOOT before making 16G SD copy (prevents expansion)"
echo "4. Use SD Card Copier to make 16G copy"
echo ""
