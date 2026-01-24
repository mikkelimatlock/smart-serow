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
    args = parser.parse_args()

    # Build
    if not args.deploy_only:
        print()
        if not build(clean=args.clean):
            print("Build failed!")
            sys.exit(1)

    # Deploy
    if not args.build_only:
        print()
        restart = not args.no_restart
        if not deploy(restart=restart):
            print("Deploy failed!")
            sys.exit(1)

    print()
    print("=== All done! ===")


if __name__ == "__main__":
    main()
