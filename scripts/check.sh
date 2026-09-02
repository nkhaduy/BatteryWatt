#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift test
plutil -lint Resources/Info.plist
bash -n scripts/*.sh
git diff --check

if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --no-banner --redact --source .
fi

if rg -n -I --hidden \
    --glob '!/.git/**' \
    --glob '!/.build/**' \
    --glob '!/build/**' \
    --glob '!/dist/**' \
    '(BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]+|npm_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-)' .; then
    echo "Possible secret material found." >&2
    exit 1
fi

echo "BatteryWatt checks passed."
