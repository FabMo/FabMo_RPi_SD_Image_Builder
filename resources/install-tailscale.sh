#!/bin/bash
# Install Tailscale for optional remote support access
# This script installs Tailscale but does NOT enable or start the service
# Users must explicitly opt-in to activate remote support

set -e

echo "Installing Tailscale for optional remote support..."

# Add Tailscale's package signing key and repository
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bookworm.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Update package lists
apt-get update

# Install Tailscale
apt-get install -y tailscale

# IMPORTANT: Disable the service by default - users must opt-in
systemctl stop tailscaled 2>/dev/null || true
systemctl disable tailscaled

echo "Tailscale installed successfully (disabled by default)"
echo "To enable remote support, run: /fabmo-support/scripts/enable-tailscale-support.sh"
