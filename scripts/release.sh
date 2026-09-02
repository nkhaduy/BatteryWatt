#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"

"$ROOT_DIR/scripts/check.sh"
"$ROOT_DIR/scripts/package-dmg.sh" "$VERSION"

echo "Release artifacts are in $ROOT_DIR/dist"
