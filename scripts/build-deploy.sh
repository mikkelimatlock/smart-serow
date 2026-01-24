#!/bin/bash
# Wrapper for build-deploy.py
# Usage: ./build-deploy.sh [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/build-deploy.py" "$@"
