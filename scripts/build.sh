#!/bin/bash
# Build script for Smart Serow Flutter UI
# Run this in WSL2 with flutter-elinux installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UI_DIR="$PROJECT_ROOT/pi/ui"

echo "=== Smart Serow Build ==="
echo "Project: $UI_DIR"

# Check for flutter-elinux
if ! command -v flutter-elinux &> /dev/null; then
    echo "ERROR: flutter-elinux not found in PATH"
    echo "Install it or check your PATH"
    echo ""
    echo "Current PATH: $PATH"
    which flutter 2>/dev/null && echo "Found flutter at: $(which flutter)"
    exit 1
fi

echo "Using: $(which flutter-elinux)"

# Cross-compilation toolchain for ARM64
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export AR=aarch64-linux-gnu-ar
export LD=aarch64-linux-gnu-ld
# CMake-specific vars
export CMAKE_C_COMPILER=aarch64-linux-gnu-gcc
export CMAKE_CXX_COMPILER=aarch64-linux-gnu-g++

echo "Cross-compiler: $CXX"

cd "$UI_DIR"

# Prepare assets (fonts, images)
PREPARE_SCRIPT="$SCRIPT_DIR/prepare_assets.sh"
if [ -x "$PREPARE_SCRIPT" ]; then
    echo "Preparing assets..."
    "$PREPARE_SCRIPT"
else
    echo "WARNING: $PREPARE_SCRIPT not found or not executable"
fi

# Initialize elinux project if not already configured
if [ ! -d "elinux" ]; then
    echo "Initializing elinux project structure..."
    flutter-elinux create . --project-name smartserow_ui --org com.smartserow
fi

# Clean CMake cache on --clean flag
# (CMake caches compiler choice, so stale cache = wrong linker)
if [ "${1:-}" = "--clean" ]; then
    echo "Cleaning CMake cache..."
    rm -rf build/elinux/arm64
fi

echo "Fetching dependencies..."
flutter-elinux pub get

echo "Building for ARM64 (elinux) with DRM-GBM backend..."

# Use Pi sysroot if available (for proper cross-linking)
SYSROOT_FLAG=""
if [ -d "$PROJECT_ROOT/pi_sysroot" ]; then
    echo "Using Pi sysroot: $PROJECT_ROOT/pi_sysroot"
    SYSROOT_FLAG="--target-sysroot=$PROJECT_ROOT/pi_sysroot"
fi

flutter-elinux build elinux \
    --target-arch=arm64 \
    --target-backend-type=gbm \
    --target-compiler-triple=aarch64-linux-gnu \
    $SYSROOT_FLAG \
    --release

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
