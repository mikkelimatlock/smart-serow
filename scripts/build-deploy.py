#!/usr/bin/env python3
"""One-click build and deploy for Smart Serow.

Combines build.py and deploy.py with sensible defaults.
Defaults to --restart since that's usually what you want.
"""

import argparse
import sys
from pathlib import Path

# Import sibling modules
sys.path.insert(0, str(Path(__file__).parent))
from build import build
from deploy import deploy
from deploy_backend import deploy as deploy_backend


def main():
    parser = argparse.ArgumentParser(
        description="Build and deploy Smart Serow in one step",
    )
    parser.add_argument(
        "--clean", "-c",
        action="store_true",
        help="Clean CMake cache before building",
    )
    parser.add_argument(
        "--no-restart",
        action="store_true",
        help="Don't restart service after deploy (default: restart)",
    )
    parser.add_argument(
        "--build-only",
        action="store_true",
        help="Only build, don't deploy",
    )
    parser.add_argument(
        "--deploy-only",
        action="store_true",
        help="Only deploy, don't build",
    )
    parser.add_argument(
        "--ui",
        action="store_true",
        help="Build/deploy UI only (no backend)",
    )
    parser.add_argument(
        "--backend",
        action="store_true",
        help="Deploy backend only (no UI, no build)",
    )
    args = parser.parse_args()

    # Default: both UI and backend if neither flag specified
    do_ui = args.ui or not args.backend
    do_backend = args.backend or not args.ui

    restart = not args.no_restart

    # Build UI (only if doing UI and not deploy-only)
    if do_ui and not args.deploy_only:
        print()
        if not build(clean=args.clean):
            print("UI build failed!")
            sys.exit(1)

    # Deploy backend FIRST (no build step needed - it's Python)
    # Backend must be up before UI connects to WebSocket
    if do_backend and not args.build_only:
        print()
        if not deploy_backend(restart=restart):
            print("Backend deploy failed!")
            sys.exit(1)

    # Deploy UI after backend is ready
    if do_ui and not args.build_only:
        print()
        if not deploy(restart=restart):
            print("UI deploy failed!")
            sys.exit(1)

    print()
    print("=== All done! ===")


if __name__ == "__main__":
    main()
