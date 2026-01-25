#!/usr/bin/env python3
"""Deploy script for Smart Serow Flutter UI.

Pushes build bundle to Pi and optionally restarts service.
"""

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
CONFIG_FILE = SCRIPT_DIR / "deploy_target.json"
BUILD_DIR = PROJECT_ROOT / "pi" / "ui" / "build" / "elinux" / "arm64" / "release" / "bundle"
CONFIG_SRC = PROJECT_ROOT / "pi" / "ui" / "config.json"
IMAGES_SRC = PROJECT_ROOT / "extra" / "images"


def run(cmd: list[str], check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    """Run a command."""
    print(f"  → {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, **kwargs)


def load_config() -> dict:
    """Load deploy target configuration."""
    if not CONFIG_FILE.exists():
        print(f"ERROR: Config file not found: {CONFIG_FILE}")
        print("Create it based on deploy_target.sample.json")
        sys.exit(1)

    with open(CONFIG_FILE) as f:
        return json.load(f)


def deploy(restart: bool = False) -> bool:
    """Deploy to Pi. Returns True on success."""
    config = load_config()

    pi_user = config["user"]
    pi_host = config["host"]
    remote_path = config["remote_path"]
    service_name = config["service_name"]

    ssh_target = f"{pi_user}@{pi_host}"

    print("=== Smart Serow Deploy ===")
    print(f"Target: {ssh_target}:{remote_path}")
    print(f"Source: {BUILD_DIR}")

    if not BUILD_DIR.exists():
        print("ERROR: Build directory not found. Run build.py first.")
        return False

    # Sync build to Pi
    print()
    print("Syncing files...")
    run([
        "rsync", "-avz", "--delete",
        f"{BUILD_DIR}/",
        f"{ssh_target}:{remote_path}/bundle/",
    ])

    # Sync config.json (sits next to executable in bundle)
    if CONFIG_SRC.exists():
        print()
        print("Syncing config.json...")
        run([
            "rsync", "-avz",
            str(CONFIG_SRC),
            f"{ssh_target}:{remote_path}/bundle/config.json",
        ])
    else:
        print()
        print("Note: No config.json found, using defaults")

    # Sync images to assets path
    if IMAGES_SRC.exists():
        assets_path = config.get("assets_path", f"{remote_path}/assets")
        print()
        print(f"Syncing images to {assets_path}...")
        run([
            "rsync", "-avz",
            f"{IMAGES_SRC}/",
            f"{ssh_target}:{assets_path}/",
        ])
    else:
        print()
        print("Note: No extra/images folder found, skipping image sync")

    # Restart service if requested
    if restart:
        print()
        print(f"Restarting service: {service_name}")
        run(["ssh", ssh_target, f"sudo systemctl restart {service_name}"])
        time.sleep(2)
        run(["ssh", ssh_target, f"systemctl status {service_name} --no-pager"], check=False)
    else:
        print()
        print("Deploy complete. To restart service, run:")
        print(f"  ssh {ssh_target} 'sudo systemctl restart {service_name}'")
        print()
        print("Or run this script with --restart flag")

    return True


def main():
    parser = argparse.ArgumentParser(description="Deploy Smart Serow to Pi")
    parser.add_argument(
        "--restart", "-r",
        action="store_true",
        help="Restart the systemd service after deploy",
    )
    args = parser.parse_args()

    success = deploy(restart=args.restart)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
