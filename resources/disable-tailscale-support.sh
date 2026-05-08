#!/bin/bash
# Disable Tailscale Remote Support for FabMo
# This script deactivates remote support access
#
# Usage: sudo /opt/fabmo/scripts/disable-tailscale-support.sh

set -e

# Must run as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${YELLOW}Disabling Tailscale remote support...${NC}"
echo ""

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo "Tailscale is not installed. Nothing to disable."
    exit 0
fi

# Disconnect from Tailscale network
echo "Disconnecting from Tailscale network..."
tailscale down 2>/dev/null || true

# Stop and disable the service
echo "Stopping Tailscale service..."
systemctl stop tailscaled 2>/dev/null || true
systemctl disable tailscaled 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Tailscale remote support is now DISABLED${NC}"
echo ""
echo "Your system is no longer accessible via Tailscale."
echo "To re-enable support, run: sudo /opt/fabmo/scripts/enable-tailscale-support.sh"
echo ""
