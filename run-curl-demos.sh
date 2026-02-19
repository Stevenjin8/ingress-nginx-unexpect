#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${INGRESS_ADDR:-172.19.100.200}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/run-curl-ingress-regex.sh" "$TARGET"
echo
"${SCRIPT_DIR}/run-curl-trailing-redirect.sh" "$TARGET"
