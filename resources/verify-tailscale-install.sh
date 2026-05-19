#!/bin/bash
# Verify Tailscale installation and paths are correct
# Run this after building the FabMo image to verify everything is in place

echo "========================================"
echo "  Tailscale Installation Verification"
echo "========================================"
echo ""

ERRORS=0
WARNINGS=0

# Check Tailscale binary
echo -n "Checking Tailscale binary... "
if command -v tailscale &> /dev/null; then
    echo "✓ Found at $(which tailscale)"
else
    echo "✗ NOT FOUND"
    ((ERRORS++))
fi

# Check tailscaled service
echo -n "Checking tailscaled service... "
if systemctl list-unit-files | grep -q tailscaled.service; then
    STATUS=$(systemctl is-enabled tailscaled 2>&1)
    if [ "$STATUS" = "disabled" ]; then
        echo "✓ Installed and DISABLED (correct)"
    else
        echo "⚠ Installed but status: $STATUS (should be disabled)"
        ((WARNINGS++))
    fi
else
    echo "✗ NOT FOUND"
    ((ERRORS++))
fi

# Check directory structure
echo -n "Checking /fabmo-support/ directory... "
if [ -d "/fabmo-support" ]; then
    echo "✓ Exists"
else
    echo "✗ MISSING"
    ((ERRORS++))
fi

echo -n "Checking /fabmo-support/scripts/ directory... "
if [ -d "/fabmo-support/scripts" ]; then
    echo "✓ Exists"
else
    echo "✗ MISSING"
    ((ERRORS++))
fi

# Check scripts
echo ""
echo "Checking management scripts:"

SCRIPTS=(
    "enable-tailscale-support.sh"
    "disable-tailscale-support.sh"
    "check-tailscale-status.sh"
)

for SCRIPT in "${SCRIPTS[@]}"; do
    echo -n "  - $SCRIPT... "
    if [ -f "/fabmo-support/scripts/$SCRIPT" ]; then
        if [ -x "/fabmo-support/scripts/$SCRIPT" ]; then
            echo "✓ Exists and executable"
        else
            echo "⚠ Exists but NOT executable"
            ((WARNINGS++))
        fi
    else
        echo "✗ MISSING"
        ((ERRORS++))
    fi
done

# Check documentation
echo ""
echo "Checking documentation:"

echo -n "  - /fabmo-support/README-TAILSCALE.txt... "
if [ -f "/fabmo-support/README-TAILSCALE.txt" ]; then
    echo "✓ Exists"
else
    echo "✗ MISSING"
    ((ERRORS++))
fi

echo -n "  - /home/pi/Desktop/README-TAILSCALE.txt... "
if [ -f "/home/pi/Desktop/README-TAILSCALE.txt" ]; then
    echo "✓ Exists"
else
    echo "⚠ Missing (not critical, but recommended)"
    ((WARNINGS++))
fi

# Check for OLD locations (should not exist)
echo ""
echo "Checking for old locations (should NOT exist):"

echo -n "  - /opt/fabmo/scripts/... "
if [ -d "/opt/fabmo/scripts" ] && ls /opt/fabmo/scripts/*tailscale* &> /dev/null; then
    echo "⚠ FOUND - Old scripts still present, should be removed"
    ((WARNINGS++))
else
    echo "✓ Not found (correct)"
fi

echo -n "  - /opt/fabmo/README-TAILSCALE.txt... "
if [ -f "/opt/fabmo/README-TAILSCALE.txt" ]; then
    echo "⚠ FOUND - Old README still present, should be removed"
    ((WARNINGS++))
else
    echo "✓ Not found (correct)"
fi

# Summary
echo ""
echo "========================================"
echo "  Summary"
echo "========================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Tailscale is correctly installed."
    echo ""
    echo "Next steps:"
    echo "  - Test enable: sudo /fabmo-support/scripts/enable-tailscale-support.sh"
    echo "  - Check status: /fabmo-support/scripts/check-tailscale-status.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ Installation complete with $WARNINGS warning(s)"
    echo "Review warnings above."
    exit 0
else
    echo "✗ Installation has $ERRORS error(s) and $WARNINGS warning(s)"
    echo "Review errors above and re-run build script."
    exit 1
fi
