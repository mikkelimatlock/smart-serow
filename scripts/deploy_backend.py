#!/usr/bin/env python3
"""Deploy script for Smart Serow Python backend.

Pushes backend source to Pi and optionally restarts service.
Completely independent from UI deploy.
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
BACKEND_DIR = PROJECT_ROOT / "pi" / "backend"


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
    """Deploy backend to Pi. Returns True on success."""
    config = load_config()

    pi_user = config["user"]
    pi_host = config["host"]

    # Backend-specific config (with defaults)
    remote_path = config.get("backend_path", "/opt/smartserow-backend")
    service_name = config.get("backend_service", "smartserow-backend")

    ssh_target = f"{pi_user}@{pi_host}"

    print("=== Smart Serow Backend Deploy ===")
    print(f"Target: {ssh_target}:{remote_path}")
    print(f"Source: {BACKEND_DIR}")

    if not BACKEND_DIR.exists():
        print(f"ERROR: Backend directory not found: {BACKEND_DIR}")
        return False

    # Ensure remote directory exists
    print()
    print("Ensuring remote directory...")
    run(["ssh", ssh_target, f"mkdir -p {remote_path}"])

    # Sync backend source to Pi
    # Exclude __pycache__, .venv, etc.
    print()
    print("Syncing files...")
    run([
        "rsync", "-avz", "--delete",
        "--exclude", "__pycache__",
        "--exclude", "*.pyc",
        "--exclude", ".venv",
        "--exclude", ".ruff_cache",
        f"{BACKEND_DIR}/",
        f"{ssh_target}:{remote_path}/",
    ])

    # Run uv sync to install/update dependencies
    # Use full path since non-interactive SSH doesn't load .bashrc
    print()
    print("Running uv sync...")
    result = run(
        ["ssh", ssh_target, f"cd {remote_path} && ~/.local/bin/uv sync"],
        check=False,
    )
    if result.returncode != 0:
        print("WARNING: uv sync failed - dependencies may be out of date")
        print("Make sure uv is installed on Pi: curl -LsSf https://astral.sh/uv/install.sh | sh")

    # Restart service if requested
    if restart:
        print()
        print(f"Restarting service: {service_name}")
        run(["ssh", ssh_target, f"sudo systemctl restart {service_name}"], check=False)
        time.sleep(2)
        run(["ssh", ssh_target, f"systemctl status {service_name} --no-pager"], check=False)
    else:
        print()
        print("Deploy complete. To restart service, run:")
        print(f"  ssh {ssh_target} 'sudo systemctl restart {service_name}'")
        print()
        print("Or run this script with --restart flag")

    print()
    print("Note: First-time setup on Pi requires uv to be installed:")
    print(f"  ssh {ssh_target}")
    print("  curl -LsSf https://astral.sh/uv/install.sh | sh")

    return True


def main():
    parser = argparse.ArgumentParser(description="Deploy Smart Serow backend to Pi")
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
