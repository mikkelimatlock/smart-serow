#!/usr/bin/env python3
"""Build script for Smart Serow Flutter UI.

Run this in WSL2 with flutter-elinux installed.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
UI_DIR = PROJECT_ROOT / "pi" / "ui"
BUILD_OUTPUT = UI_DIR / "build" / "elinux" / "arm64" / "release" / "bundle"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run a command, exit on failure."""
    print(f"  → {' '.join(cmd)}")
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode)
    return result


def check_flutter_elinux() -> str:
    """Check if flutter-elinux is available, return path."""
    result = subprocess.run(
        ["which", "flutter-elinux"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("ERROR: flutter-elinux not found in PATH")
        print("Install it or check your PATH")
        print(f"\nCurrent PATH: {os.environ.get('PATH', '')}")
        sys.exit(1)
    return result.stdout.strip()


def set_cross_compile_env():
    """Set environment variables for ARM64 cross-compilation."""
    env_vars = {
        "CC": "aarch64-linux-gnu-gcc",
        "CXX": "aarch64-linux-gnu-g++",
        "AR": "aarch64-linux-gnu-ar",
        "LD": "aarch64-linux-gnu-ld",
        "CMAKE_C_COMPILER": "aarch64-linux-gnu-gcc",
        "CMAKE_CXX_COMPILER": "aarch64-linux-gnu-g++",
    }
    os.environ.update(env_vars)
    return env_vars


def build(clean: bool = False) -> bool:
    """Run the build process. Returns True on success."""
    print("=== Smart Serow Build ===")
    print(f"Project: {UI_DIR}")

    # Check flutter-elinux
    flutter_path = check_flutter_elinux()
    print(f"Using: {flutter_path}")

    # Set cross-compilation env
    env_vars = set_cross_compile_env()
    print(f"Cross-compiler: {env_vars['CXX']}")

    os.chdir(UI_DIR)

    # Prepare assets (fonts, images)
    prepare_script = SCRIPT_DIR / "prepare_assets.sh"
    if prepare_script.exists():
        print("Preparing assets...")
        run(["bash", str(prepare_script)])
    else:
        print(f"WARNING: {prepare_script} not found")

    # Initialize elinux project if needed
    elinux_dir = UI_DIR / "elinux"
    if not elinux_dir.exists():
        print("Initializing elinux project structure...")
        run([
            "flutter-elinux", "create", ".",
            "--project-name", "smartserow_ui",
            "--org", "com.smartserow",
        ])

    # Clean if requested
    if clean:
        cache_dir = UI_DIR / "build" / "elinux" / "arm64"
        if cache_dir.exists():
            print("Cleaning CMake cache...")
            shutil.rmtree(cache_dir)

    # Fetch dependencies
    print("Fetching dependencies...")
    run(["flutter-elinux", "pub", "get"])

    # Build command
    print("Building for ARM64 (elinux) with DRM-GBM backend...")

    build_cmd = [
        "flutter-elinux", "build", "elinux",
        "--target-arch=arm64",
        "--target-backend-type=gbm",
        "--target-compiler-triple=aarch64-linux-gnu",
        "--release",
    ]

    # Add sysroot if available
    sysroot = PROJECT_ROOT / "pi_sysroot"
    if sysroot.exists():
        print(f"Using Pi sysroot: {sysroot}")
        build_cmd.append(f"--target-sysroot={sysroot}")

    run(build_cmd)

    # Verify output
    if BUILD_OUTPUT.exists():
        print()
        print("=== Build Complete ===")
        print(f"Output: {BUILD_OUTPUT}")
        for f in BUILD_OUTPUT.iterdir():
            size = f.stat().st_size
            print(f"  {f.name}: {size:,} bytes")
        return True
    else:
        print(f"ERROR: Build output not found at {BUILD_OUTPUT}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Build Smart Serow Flutter UI")
    parser.add_argument(
        "--clean", "-c",
        action="store_true",
        help="Clean CMake cache before building",
    )
    args = parser.parse_args()

    success = build(clean=args.clean)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
