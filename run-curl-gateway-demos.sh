#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${GATEWAY_ADDR:-172.19.100.202}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/run-curl-gateway-regex.sh" "$TARGET"
echo
"${SCRIPT_DIR}/run-curl-gateway-trailing-redirect.sh" "$TARGET"
echo
"${SCRIPT_DIR}/run-curl-gateway-path-normalization.sh" "$TARGET"
