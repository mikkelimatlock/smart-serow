#!/bin/bash
# One-time setup script for Smart Serow on Raspberry Pi
# Run this ON the Pi itself

set -e

echo "=== Smart Serow Pi Setup ==="

# Check if running on Pi (arm architecture)
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
    echo "WARNING: This doesn't look like a Pi (arch: $ARCH)"
    echo "Continuing anyway..."
fi

APP_DIR="/opt/smartserow"
SERVICE_FILE="/etc/systemd/system/smartserow-ui.service"

# Create app directory
echo "Creating app directory: $APP_DIR"
sudo mkdir -p "$APP_DIR/bundle"
sudo chown -R pi:pi "$APP_DIR"

# Install runtime dependencies for flutter-elinux
echo "Installing runtime dependencies..."
sudo apt-get update
sudo apt-get install -y \
    libgl1-mesa-dri \
    libgles2-mesa \
    libegl1-mesa \
    libdrm2 \
    libgbm1 \
    libinput10 \
    libudev1 \
    fonts-noto

# For X11 debug mode (optional but useful)
sudo apt-get install -y \
    xorg \
    xinit \
    libx11-6 \
    libxkbcommon-x11-0

# Copy systemd service
echo "Installing systemd service..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/smartserow-ui.service" ]; then
    sudo cp "$SCRIPT_DIR/smartserow-ui.service" "$SERVICE_FILE"
else
    echo "WARNING: Service file not found at $SCRIPT_DIR/smartserow-ui.service"
    echo "Copy it manually to $SERVICE_FILE"
fi

# Enable service
echo "Enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable smartserow-ui

# Add pi user to required groups for DRM/KMS access
echo "Setting up permissions..."
sudo usermod -aG video pi
sudo usermod -aG input pi
sudo usermod -aG render pi 2>/dev/null || true

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Deploy the app: run deploy.sh from your dev machine"
echo "2. Start service:  sudo systemctl start smartserow-ui"
echo "3. Or reboot:      sudo reboot"
echo ""
echo "Useful commands:"
echo "  systemctl status smartserow-ui    # Check status"
echo "  journalctl -u smartserow-ui -f    # View logs"
echo ""
