#!/bin/bash
# Build script for Smart Serow Flutter UI
# Run this in WSL2 with flutter-elinux installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UI_DIR="$PROJECT_ROOT/pi/ui"

echo "=== Smart Serow Build ==="
echo "Project: $UI_DIR"

cd "$UI_DIR"

# Clean previous build (optional, comment out for faster incremental builds)
# flutter-elinux clean

echo "Fetching dependencies..."
flutter-elinux pub get

echo "Building for ARM64 (elinux)..."
flutter-elinux build elinux --target-arch=arm64 --release

BUILD_OUTPUT="$UI_DIR/build/elinux/arm64/release/bundle"

if [ -d "$BUILD_OUTPUT" ]; then
    echo ""
    echo "=== Build Complete ==="
    echo "Output: $BUILD_OUTPUT"
    ls -lh "$BUILD_OUTPUT"
else
    echo "ERROR: Build output not found at $BUILD_OUTPUT"
    exit 1
fi
