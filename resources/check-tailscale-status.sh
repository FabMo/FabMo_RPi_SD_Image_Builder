#!/bin/bash
# Check Tailscale Remote Support Status for FabMo
# Shows whether remote support is enabled and connection details
#
# Usage: /opt/fabmo/scripts/check-tailscale-status.sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  FabMo Remote Support Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${YELLOW}Status:${NC} Tailscale is installed but not configured"
    echo ""
    echo "Remote support capability: Available"
    echo "Current state: Inactive (not connected)"
    echo ""
    echo "To enable remote support:"
    echo "  sudo /opt/fabmo/scripts/enable-tailscale-support.sh"
    echo ""
    exit 0
fi

# Check if service is running
if systemctl is-active --quiet tailscaled; then
    echo -e "${GREEN}✓ Remote support is ACTIVE${NC}"
    echo ""
    
    # Get Tailscale status
    echo "Connection Details:"
    echo "==================="
    tailscale status
    echo ""
    
    # Get IP addresses
    echo "Tailscale IP Addresses:"
    tailscale ip -4 2>/dev/null || echo "  IPv4: Not available"
    tailscale ip -6 2>/dev/null || echo "  IPv6: Not available"
    echo ""
    
    echo "FabMo Dashboard Access:"
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
    if [ -n "$TAILSCALE_IP" ]; then
        echo "  http://$TAILSCALE_IP"
    fi
    echo ""
    
    echo "SSH Access:"
    echo "  ssh pi@$TAILSCALE_IP"
    echo ""
    
    echo "To disable remote support:"
    echo "  sudo /opt/fabmo/scripts/disable-tailscale-support.sh"
else
    echo -e "${RED}✗ Remote support is DISABLED${NC}"
    echo ""
    echo "Tailscale is installed but not connected."
    echo ""
    echo "To enable remote support:"
    echo "  sudo /opt/fabmo/scripts/enable-tailscale-support.sh"
fi

echo ""
echo "Web Console: https://login.tailscale.com"
echo ""
