#!/bin/bash
# One-time setup script for Smart Serow Backend on Raspberry Pi
# Run this ON the Pi itself

set -e

echo "=== Smart Serow Backend Setup ==="

PI_USER="${USER:-$(whoami)}"
echo "Setting up for user: $PI_USER"

BACKEND_DIR="/opt/smartserow-backend"
SERVICE_FILE="/etc/systemd/system/smartserow-backend.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create backend directory
echo "Creating backend directory: $BACKEND_DIR"
sudo mkdir -p "$BACKEND_DIR"
sudo chown -R "$PI_USER:$PI_USER" "$BACKEND_DIR"

# Install uv if not present
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "  → Restart your shell or run: source ~/.bashrc"
else
    echo "uv already installed: $(uv --version)"
fi

# Install gpsd and GPIO support
echo "Installing system packages..."
sudo apt-get update
sudo apt-get install -y gpsd gpsd-clients python3-rpi.gpio

# Configure gpsd (user needs to edit DEVICES)
GPSD_CONFIG="/etc/default/gpsd"
echo ""
echo "gpsd installed. Configure your GPS device:"
echo "  sudo nano $GPSD_CONFIG"
echo "  Set DEVICES=\"/dev/ttyUSB0\" (or your GPS serial port)"
echo "  Set GPSD_OPTIONS=\"-n\""
echo "  Then: sudo systemctl restart gpsd"
echo ""

# Install systemd service
echo "Installing systemd service..."
if [ -f "$SCRIPT_DIR/smartserow-backend.service" ]; then
    sed -e "s/User=.*/User=$PI_USER/" \
        -e "s/Group=.*/Group=$PI_USER/" \
        -e "s|/home/pi|/home/$PI_USER|g" \
        "$SCRIPT_DIR/smartserow-backend.service" | sudo tee "$SERVICE_FILE" > /dev/null
    echo "  → Installed to $SERVICE_FILE"
else
    echo "WARNING: Service template not found at $SCRIPT_DIR/smartserow-backend.service"
    echo "Copy it manually to $SERVICE_FILE"
fi

# Enable service (but don't start - no code deployed yet)
echo "Enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable smartserow-backend

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Configure gpsd: sudo nano /etc/default/gpsd"
echo "2. Deploy backend: python3 scripts/deploy_backend.py (from dev machine)"
echo "3. On Pi, create venv and install deps:"
echo "     cd $BACKEND_DIR"
echo "     uv venv --system-site-packages  # Allows access to apt packages"
echo "     uv sync"
echo "4. Start service: sudo systemctl start smartserow-backend"
echo ""
echo "Useful commands:"
echo "  systemctl status smartserow-backend"
echo "  journalctl -u smartserow-backend -f"
echo "  curl http://localhost:5000/health"
echo "  gpsmon  # test gpsd directly"
echo ""
