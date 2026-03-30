#!/data/data/com.termux/files/usr/bin/bash
# Ensure bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

echo "Test script - LF safe"

update_progress() {
    echo "Progress OK"
}

update_progress
