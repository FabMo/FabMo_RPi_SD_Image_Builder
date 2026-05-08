#!/bin/bash
# Enable Tailscale Remote Support for FabMo
# This script activates remote support access via Tailscale VPN
# 
# Usage: sudo /opt/fabmo/scripts/enable-tailscale-support.sh

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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  FabMo Remote Support Activation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "This will enable secure remote support access to your FabMo system"
echo "via Tailscale VPN (tailscale.com)."
echo ""
echo -e "${YELLOW}What this means:${NC}"
echo "  - FabMo support team can access your system remotely"
echo "  - All connections are encrypted via WireGuard VPN"
echo "  - No changes to your local network configuration"
echo "  - You can disable this at any time"
echo ""
echo -e "${YELLOW}Privacy & Security:${NC}"
echo "  - Only authorized FabMo support staff can connect"
echo "  - All access is logged"
echo "  - You can revoke access from https://login.tailscale.com"
echo ""
echo -e "${YELLOW}Note:${NC} This requires an authentication key from FabMo support."
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Activation cancelled."
    exit 0
fi

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}ERROR: Tailscale is not installed.${NC}"
    echo "Please contact FabMo support for assistance."
    exit 1
fi

# Prompt for authentication key
echo ""
echo -e "${YELLOW}Please enter the Tailscale authentication key provided by FabMo support:${NC}"
read -p "Auth Key: " AUTH_KEY

if [ -z "$AUTH_KEY" ]; then
    echo -e "${RED}ERROR: No authentication key provided.${NC}"
    exit 1
fi

# Generate a unique hostname based on machine ID
MACHINE_ID=$(cat /etc/machine-id | cut -c1-8)
HOSTNAME="fabmo-$MACHINE_ID"

echo ""
echo "Enabling Tailscale service..."
systemctl enable tailscaled
systemctl start tailscaled

echo "Connecting to Tailscale network..."
echo "(This may take a moment...)"

# Authenticate with Tailscale
# --ssh enables Tailscale SSH for better security and auditability
# --accept-routes allows access to other Tailscale resources if configured
tailscale up \
    --authkey="$AUTH_KEY" \
    --hostname="$HOSTNAME" \
    --ssh \
    --accept-routes \
    --shields-up=false

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Tailscale remote support is now ACTIVE${NC}"
    echo ""
    echo "Connection details:"
    tailscale status
    echo ""
    echo -e "${GREEN}Your FabMo unit is now accessible for remote support.${NC}"
    echo ""
    echo "Useful commands:"
    echo "  - Check status:   tailscale status"
    echo "  - View IP:        tailscale ip"
    echo "  - Disconnect:     sudo /opt/fabmo/scripts/disable-tailscale-support.sh"
    echo "  - Web console:    https://login.tailscale.com"
    echo ""
else
    echo -e "${RED}ERROR: Failed to connect to Tailscale.${NC}"
    echo "Please verify the authentication key and try again."
    echo "If problems persist, contact FabMo support."
    exit 1
fi
