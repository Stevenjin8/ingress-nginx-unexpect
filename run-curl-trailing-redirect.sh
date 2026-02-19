#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${INGRESS_ADDR:-172.19.100.200}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running trailing-redirect curl demos against: ${TARGET}"

echo
echo "=== Trailing slash redirect (/bytes) ==="
echo "+ curl -vsS -HHost:trailing-slash.example.com ${TARGET}/bytes"
curl -vsS -H "Host:trailing-slash.example.com" "${TARGET}/bytes"
