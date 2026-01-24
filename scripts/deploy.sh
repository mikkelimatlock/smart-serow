#!/bin/bash
# Deploy script for Smart Serow Flutter UI
# Pushes build bundle to Pi and optionally restarts service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/deploy_target.json"

# Parse config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

HOST=$(jq -r '.host' "$CONFIG_FILE")
REMOTE_PATH=$(jq -r '.remote_path' "$CONFIG_FILE")
SERVICE_NAME=$(jq -r '.service_name' "$CONFIG_FILE")

BUILD_DIR="$PROJECT_ROOT/pi/ui/build/elinux/arm64/release/bundle"

echo "=== Smart Serow Deploy ==="
echo "Target: $HOST:$REMOTE_PATH"
echo "Source: $BUILD_DIR"

if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found. Run build.sh first."
    exit 1
fi

# Sync build to Pi
echo ""
echo "Syncing files..."
rsync -avz --delete \
    "$BUILD_DIR/" \
    "$HOST:$REMOTE_PATH/bundle/"

# Restart service if requested
RESTART="${1:-}"
if [ "$RESTART" = "--restart" ] || [ "$RESTART" = "-r" ]; then
    echo ""
    echo "Restarting service: $SERVICE_NAME"
    ssh "$HOST" "sudo systemctl restart $SERVICE_NAME"
    sleep 2
    ssh "$HOST" "systemctl status $SERVICE_NAME --no-pager"
else
    echo ""
    echo "Deploy complete. To restart service, run:"
    echo "  ssh $HOST 'sudo systemctl restart $SERVICE_NAME'"
    echo ""
    echo "Or run this script with --restart flag"
fi
