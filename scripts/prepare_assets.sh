#!/bin/bash
# prepare_assets.sh - Prepares fonts and images for Flutter build
# Run this before 'flutter build' to ensure assets are in place
#
# This script handles:
# - DIN1451 font: symlinks from extra/ if present, otherwise downloads Noto Sans as fallback
# - Dashboard image: symlinks from extra/ if present, otherwise skipped (handled at runtime)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

UI_DIR="$PROJECT_ROOT/pi/ui"
FONTS_DIR="$UI_DIR/fonts"
IMAGES_DIR="$UI_DIR/assets/images"
EXTRA_FONTS="$PROJECT_ROOT/extra/fonts"
EXTRA_IMAGES="$PROJECT_ROOT/extra/images"

# Noto Sans download URLs (Google Fonts)
NOTO_SANS_BASE="https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
NOTO_REGULAR="$NOTO_SANS_BASE/NotoSans-Regular.ttf"
NOTO_BOLD="$NOTO_SANS_BASE/NotoSans-Bold.ttf"
NOTO_LIGHT="$NOTO_SANS_BASE/NotoSans-Light.ttf"

echo "=== Smart Serow Asset Preparation ==="

# --- FONTS ---
echo ""
echo "--- Fonts ---"

# Ensure Noto Sans fallbacks exist
download_noto() {
    local weight=$1
    local url=$2
    local dest="$FONTS_DIR/NotoSans-${weight}.ttf"

    if [ ! -f "$dest" ]; then
        echo "Downloading Noto Sans $weight..."
        curl -sL "$url" -o "$dest" || {
            echo "Warning: Failed to download Noto Sans $weight"
            return 1
        }
        echo "  -> Downloaded $dest"
    else
        echo "  Noto Sans $weight already present"
    fi
}

download_noto "Regular" "$NOTO_REGULAR"
download_noto "Bold" "$NOTO_BOLD"
download_noto "Light" "$NOTO_LIGHT"

# DIN1451 - symlink if available, otherwise use Noto Sans
DIN_TARGET="$FONTS_DIR/din1451alt.ttf"
DIN_SOURCE="$EXTRA_FONTS/din1451alt.ttf"

# Remove old symlink/file to ensure fresh state
rm -f "$DIN_TARGET"

if [ -f "$DIN_SOURCE" ]; then
    echo "DIN1451 found - linking/copying"
    # Try symlink first, fall back to copy (Windows compatibility)
    if ln -s "$DIN_SOURCE" "$DIN_TARGET" 2>/dev/null; then
        echo "  -> Linked $DIN_TARGET -> $DIN_SOURCE"
    else
        cp "$DIN_SOURCE" "$DIN_TARGET"
        echo "  -> Copied $DIN_TARGET (symlinks not supported)"
    fi
else
    echo "DIN1451 not found - using Noto Sans as fallback"
    if [ -f "$FONTS_DIR/NotoSans-Regular.ttf" ]; then
        cp "$FONTS_DIR/NotoSans-Regular.ttf" "$DIN_TARGET"
        echo "  -> Copied Noto Sans Regular as $DIN_TARGET"
    else
        echo "  ERROR: No fallback font available!"
        exit 1
    fi
fi

# --- IMAGES ---
echo ""
echo "--- Images ---"

REI_TARGET="$IMAGES_DIR/rei_default.png"
REI_SOURCE="$EXTRA_IMAGES/rei_default.png"

# Remove old symlink/file
rm -f "$REI_TARGET"

if [ -f "$REI_SOURCE" ]; then
    echo "Dashboard image found - linking/copying"
    # Try symlink first, fall back to copy (Windows compatibility)
    if ln -s "$REI_SOURCE" "$REI_TARGET" 2>/dev/null; then
        echo "  -> Linked $REI_TARGET -> $REI_SOURCE"
    else
        cp "$REI_SOURCE" "$REI_TARGET"
        echo "  -> Copied $REI_TARGET (symlinks not supported)"
    fi
else
    echo "Dashboard image not found - will use empty fallback at runtime"
    # Create a tiny transparent PNG placeholder (1x1 pixel)
    # This avoids asset not found errors while keeping the build clean
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$REI_TARGET"
    echo "  -> Created 1x1 transparent placeholder"
fi

echo ""
echo "=== Asset preparation complete ==="
echo "You can now run: flutter build linux"
