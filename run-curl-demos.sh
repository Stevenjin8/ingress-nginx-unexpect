#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${INGRESS_ADDR:-172.19.100.200}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running ingress-nginx curl demos against: ${TARGET}"

echo
echo "=== Regex ingress behavior (/uuid) ==="
echo "+ curl -vsS -HHost:regex.example.com ${TARGET}/uuid"
curl -vsS -H "Host:regex.example.com" "${TARGET}/uuid"

echo
echo "=== Regex ingress behavior (/status/200) ==="
echo "+ curl -vsS -HHost:regex.example.com ${TARGET}/status/200"
curl -vsS -H "Host:regex.example.com" "${TARGET}/status/200"

echo
echo "=== Regex ingress behavior (/headers via HEADE path) ==="
echo "+ curl -vsS -HHost:regex.example.com ${TARGET}/headers"
curl -vsS -H "Host:regex.example.com" "${TARGET}/headers"

echo
echo "=== Trailing slash redirect (/bytes) ==="
echo "+ curl -vsS -HHost:trailing-slash.example.com ${TARGET}/bytes"
curl -vsS -H "Host:trailing-slash.example.com" "${TARGET}/bytes"
