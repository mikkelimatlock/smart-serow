#!/usr/bin/env python3
"""Theme generator for Smart Serow Flutter UI.

Reads navigator from config, loads corresponding theme JSON,
and generates app_colors.dart with the colour palette.

Fallback chain: {navigator}.json -> default.json -> hardcoded defaults
"""

import json
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
UI_DIR = PROJECT_ROOT / "pi" / "ui"
THEMES_DIR = PROJECT_ROOT / "extra" / "themes"
CONFIG_FILE = UI_DIR / "config.json"
OUTPUT_FILE = UI_DIR / "lib" / "theme" / "app_colors.dart"

# Hardcoded fallback if no theme files exist at all
HARDCODED_THEME = {
    "dark": {
        "background": "#000000",
        "foreground": "#FFFFFF",
        "highlight": "#FF5555",
        "subdued": "#808080",
    },
    "bright": {
        "background": "#F0F0F0",
        "foreground": "#1A1A1A",
        "highlight": "#CC0000",
        "subdued": "#606060",
    },
}


def hex_to_flutter(hex_color: str) -> str:
    """Convert #RRGGBB to 0xFFRRGGBB format."""
    hex_clean = hex_color.lstrip("#").upper()
    return f"0xFF{hex_clean}"


def load_config() -> dict:
    """Load UI config, return empty dict if missing."""
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return {}


def load_theme(navigator: str) -> dict:
    """Load theme for navigator with fallback chain."""
    # Try navigator-specific theme
    nav_theme = THEMES_DIR / f"{navigator}.json"
    if nav_theme.exists():
        print(f"  Using theme: {nav_theme.name}")
        with open(nav_theme) as f:
            return json.load(f)

    # Try default theme
    default_theme = THEMES_DIR / "default.json"
    if default_theme.exists():
        print(f"  Fallback to: default.json")
        with open(default_theme) as f:
            return json.load(f)

    # Last resort: hardcoded
    print(f"  Using hardcoded defaults")
    return HARDCODED_THEME


def generate_dart(theme: dict) -> str:
    """Generate Dart source from theme dict."""
    dark = theme["dark"]
    bright = theme["bright"]

    return f'''import 'package:flutter/material.dart';

/// Auto-generated from theme config. Do not edit manually.
/// Run scripts/generate_theme.py to regenerate.
class AppColors {{
  AppColors._();

  // Dark theme (low ambient light)
  static const darkBackground = Color({hex_to_flutter(dark["background"])});
  static const darkForeground = Color({hex_to_flutter(dark["foreground"])});
  static const darkHighlight = Color({hex_to_flutter(dark["highlight"])});
  static const darkSubdued = Color({hex_to_flutter(dark["subdued"])});

  // Bright theme (high ambient light)
  static const brightBackground = Color({hex_to_flutter(bright["background"])});
  static const brightForeground = Color({hex_to_flutter(bright["foreground"])});
  static const brightHighlight = Color({hex_to_flutter(bright["highlight"])});
  static const brightSubdued = Color({hex_to_flutter(bright["subdued"])});
}}
'''


def main():
    print("=== Theme Generation ===")

    # Get navigator from config
    config = load_config()
    navigator = config.get("navigator", "default")
    print(f"  Navigator: {navigator}")

    # Load theme
    theme = load_theme(navigator)

    # Generate Dart
    dart_source = generate_dart(theme)

    # Ensure output directory exists
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    # Write output
    with open(OUTPUT_FILE, "w") as f:
        f.write(dart_source)

    print(f"  Generated: {OUTPUT_FILE.relative_to(PROJECT_ROOT)}")
    return True


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
