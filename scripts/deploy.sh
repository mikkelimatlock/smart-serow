#!/bin/bash
# Deploy script for Smart Serow Flutter UI
# Pushes build bundle to Pi and optionally restarts service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/deploy_target.json"
# You'll need to create this file based on deploy_target.sample.json

# Parse config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Parse JSON with Python (more universal than jq)
read_json() {
    python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['$1'])"
}

PI_USER=$(read_json user)
PI_HOST=$(read_json host)
REMOTE_PATH=$(read_json remote_path)
SERVICE_NAME=$(read_json service_name)

SSH_TARGET="$PI_USER@$PI_HOST"
BUILD_DIR="$PROJECT_ROOT/pi/ui/build/elinux/arm64/release/bundle"

echo "=== Smart Serow Deploy ==="
echo "Target: $SSH_TARGET:$REMOTE_PATH"
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
    "$SSH_TARGET:$REMOTE_PATH/bundle/"

# Restart service if requested
RESTART="${1:-}"
if [ "$RESTART" = "--restart" ] || [ "$RESTART" = "-r" ]; then
    echo ""
    echo "Restarting service: $SERVICE_NAME"
    ssh "$SSH_TARGET" "sudo systemctl restart $SERVICE_NAME"
    sleep 2
    ssh "$SSH_TARGET" "systemctl status $SERVICE_NAME --no-pager"
else
    echo ""
    echo "Deploy complete. To restart service, run:"
    echo "  ssh $SSH_TARGET 'sudo systemctl restart $SERVICE_NAME'"
    echo ""
    echo "Or run this script with --restart flag"
fi
